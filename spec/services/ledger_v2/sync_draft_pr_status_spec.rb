require "rails_helper"

RSpec.describe LedgerV2::SyncDraftPrStatus, type: :service do
  let(:run) { LedgerV2::Run.create!(runner_name: "SyncDraftPrStatus", trigger_type: :schedule) }
  let(:ticket) do
    LedgerV2::Ticket.create!(
      canonical_key: "ledger_v2:ci_success_rate:below_minimum:daily:2026-05-12",
      title: "CI 成功率が閾値を下回っています",
      status: :open,
      severity: :high,
      metric_name: "ci_success_rate",
      review_status: :not_required,
      human_decision: :none
    )
  end
  let!(:artifact) do
    LedgerV2::Artifact.create!(
      artifact_type: "ci_fix_suggestion",
      title: "CI 修正案",
      body: "rubocop を確認する",
      format: "markdown",
      review_status: :accepted,
      run: run,
      related_ticket: ticket,
      metadata_json: {
        "draft_pr" => {
          "number" => 123,
          "url" => "https://example.com/pr/123",
          "ci_status" => "pending",
          "ci_decision" => "continue",
          "failed_checks" => []
        }
      }
    )
  end

  describe ".call" do
    it "CI success を metadata と continue Event に同期する" do
      allow(LedgerV2::Flags).to receive(:enabled?).with(:auto_merge).and_return(true)
      allow(LedgerV2::Flags).to receive(:enabled?).with(:auto_deploy).and_return(true)
      allow(GithubPrService).to receive(:fetch_ci_status).with(pr_number: 123).and_return(
        {
          "pr_number" => 123,
          "pr_url" => "https://example.com/pr/123",
          "head_sha" => "abc123",
          "status" => "success",
          "conclusion" => "success",
          "failed_checks" => [],
          "check_runs" => [{ "name" => "test", "status" => "completed", "conclusion" => "success" }]
        }
      )
      allow(GithubPrService).to receive(:merge_pr).and_return(
        { "merged" => true, "sha" => "merge123", "message" => "Pull Request successfully merged" }
      )

      expect {
        described_class.call(run: run)
      }.to change {
        LedgerV2::Event.where(event_type: "draft_pr_ci_continue").count
      }.by(1)

      draft_pr = artifact.reload.metadata_json.fetch("draft_pr")
      expect(draft_pr["ci_status"]).to eq("success")
      expect(draft_pr["ci_decision"]).to eq("continue")
      expect(draft_pr["head_sha"]).to eq("abc123")
      expect(draft_pr["ci_terminal"]).to be true
      expect(draft_pr["ci_terminal_reason"]).to eq("ci_passed")
      expect(draft_pr["ci_retry_count"]).to eq(0)
      expect(draft_pr["ci_terminal_at"]).to be_present

      expect(LedgerV2::Event.where(event_type: "draft_pr_ci_terminal").count).to eq(1)
      expect(LedgerV2::Event.where(event_type: "phase_d_pr_merged").count).to eq(1)
      expect(artifact.reload.metadata_json.dig("phase_d", "execution_status")).to eq("merged")
    end

    it "CI failure を human_escalate Event に同期する" do
      allow(LedgerV2::Flags).to receive(:enabled?).with(:auto_merge).and_return(true)
      allow(LedgerV2::Flags).to receive(:enabled?).with(:auto_deploy).and_return(false)
      allow(GithubPrService).to receive(:fetch_ci_status).with(pr_number: 123).and_return(
        {
          "pr_number" => 123,
          "pr_url" => "https://example.com/pr/123",
          "head_sha" => "def456",
          "status" => "failure",
          "conclusion" => "failure",
          "failed_checks" => ["test"],
          "check_runs" => [{ "name" => "test", "status" => "completed", "conclusion" => "failure" }]
        }
      )

      expect {
        described_class.call(run: run)
      }.to change {
        LedgerV2::Event.where(event_type: "draft_pr_ci_human_escalate").count
      }.by(1)

      draft_pr = artifact.reload.metadata_json.fetch("draft_pr")
      expect(draft_pr["ci_status"]).to eq("failure")
      expect(draft_pr["ci_decision"]).to eq("human_escalate")
      expect(draft_pr["failed_checks"]).to eq(["test"])
      expect(draft_pr["ci_terminal"]).to be true
      expect(draft_pr["ci_terminal_reason"]).to eq("ci_failed")

      expect(LedgerV2::Event.where(event_type: "draft_pr_ci_terminal").count).to eq(1)
    end

    it "auto_merge が停止中なら stop Event を記録する" do
      allow(LedgerV2::Flags).to receive(:enabled?).with(:auto_merge).and_return(false)
      allow(LedgerV2::Flags).to receive(:enabled?).with(:auto_deploy).and_return(false)
      allow(GithubPrService).to receive(:fetch_ci_status).with(pr_number: 123).and_return(
        {
          "pr_number" => 123,
          "pr_url" => "https://example.com/pr/123",
          "head_sha" => "ghi789",
          "status" => "success",
          "conclusion" => "success",
          "failed_checks" => [],
          "check_runs" => []
        }
      )

      expect {
        described_class.call(run: run)
      }.to change {
        LedgerV2::Event.where(event_type: "draft_pr_ci_stop").count
      }.by(1)

      expect(artifact.reload.metadata_json.dig("draft_pr", "ci_decision")).to eq("stop")
      expect(artifact.reload.metadata_json.dig("draft_pr", "ci_terminal")).to be true
      expect(artifact.reload.metadata_json.dig("draft_pr", "ci_terminal_reason")).to eq("auto_merge_disabled")
      expect(LedgerV2::Event.where(event_type: "draft_pr_ci_terminal").count).to eq(1)
    end

    it "同じ CI 状態は重複記録しない" do
      artifact.update!(
        metadata_json: {
          "draft_pr" => {
            "number" => 123,
            "url" => "https://example.com/pr/123",
            "ci_status" => "success",
            "ci_conclusion" => "success",
            "ci_decision" => "continue",
            "ci_retry_count" => 0,
            "ci_terminal" => true,
            "ci_terminal_at" => Time.current.iso8601,
            "ci_terminal_reason" => "ci_passed",
            "failed_checks" => [],
            "head_sha" => "abc123"
          },
          "phase_d" => {
            "execution_status" => "merged",
            "merge_commit_sha" => "merge123"
          }
        }
      )
      allow(LedgerV2::Flags).to receive(:enabled?).with(:auto_merge).and_return(true)
      allow(LedgerV2::Flags).to receive(:enabled?).with(:auto_deploy).and_return(true)
      allow(GithubPrService).to receive(:fetch_ci_status).with(pr_number: 123).and_return(
        {
          "pr_number" => 123,
          "pr_url" => "https://example.com/pr/123",
          "head_sha" => "abc123",
          "status" => "success",
          "conclusion" => "success",
          "failed_checks" => [],
          "check_runs" => []
        }
      )

      expect {
        described_class.call(run: run)
      }.not_to change(LedgerV2::Event, :count)
    end

    it "CI 状態取得失敗時は sync_failed Event を記録する" do
      allow(GithubPrService).to receive(:fetch_ci_status).with(pr_number: 123).and_return(nil)

      expect {
        described_class.call(run: run)
      }.to change {
        LedgerV2::Event.where(event_type: "draft_pr_ci_sync_failed").count
      }.by(1)

      expect(artifact.reload.metadata_json.dig("draft_pr", "ci_status")).to eq("unknown")
    end

    it "CI pending は retrying Event を記録し、retry_count を増やす" do
      allow(LedgerV2::Flags).to receive(:enabled?).with(:auto_merge).and_return(true)
      allow(LedgerV2::Flags).to receive(:enabled?).with(:auto_deploy).and_return(false)
      allow(GithubPrService).to receive(:fetch_ci_status).with(pr_number: 123).and_return(
        {
          "pr_number" => 123,
          "pr_url" => "https://example.com/pr/123",
          "head_sha" => "pending123",
          "status" => "pending",
          "conclusion" => "pending",
          "failed_checks" => [],
          "check_runs" => [{ "name" => "test", "status" => "in_progress", "conclusion" => nil }]
        }
      )

      expect {
        described_class.call(run: run)
      }.to change {
        LedgerV2::Event.where(event_type: "draft_pr_ci_retrying").count
      }.by(1)

      draft_pr = artifact.reload.metadata_json.fetch("draft_pr")
      expect(draft_pr["ci_decision"]).to eq("continue")
      expect(draft_pr["ci_retry_count"]).to eq(1)
      expect(draft_pr["ci_terminal"]).to be false
      expect(draft_pr["ci_terminal_reason"]).to be_nil
    end

    it "pending が規定回数を超えると human_escalate terminal にする" do
      artifact.update!(
        metadata_json: artifact.metadata_json.deep_merge(
          "draft_pr" => {
            "ci_retry_count" => 2
          }
        )
      )
      allow(LedgerV2::Flags).to receive(:enabled?).with(:auto_merge).and_return(true)
      allow(LedgerV2::Flags).to receive(:enabled?).with(:auto_deploy).and_return(false)
      allow(GithubPrService).to receive(:fetch_ci_status).with(pr_number: 123).and_return(
        {
          "pr_number" => 123,
          "pr_url" => "https://example.com/pr/123",
          "head_sha" => "pending999",
          "status" => "pending",
          "conclusion" => "pending",
          "failed_checks" => [],
          "check_runs" => [{ "name" => "test", "status" => "in_progress", "conclusion" => nil }]
        }
      )

      expect {
        described_class.call(run: run)
      }.to change {
        LedgerV2::Event.where(event_type: "draft_pr_ci_human_escalate").count
      }.by(1)

      draft_pr = artifact.reload.metadata_json.fetch("draft_pr")
      expect(draft_pr["ci_retry_count"]).to eq(3)
      expect(draft_pr["ci_terminal"]).to be true
      expect(draft_pr["ci_terminal_reason"]).to eq("ci_pending_timeout")
      expect(LedgerV2::Event.where(event_type: "draft_pr_ci_terminal").count).to eq(1)
    end
  end
end
