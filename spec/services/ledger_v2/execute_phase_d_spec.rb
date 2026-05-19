require "rails_helper"

RSpec.describe LedgerV2::ExecutePhaseD, type: :service do
  let(:run) { LedgerV2::Run.create!(runner_name: "SyncDraftPrStatus", trigger_type: :schedule) }
  let(:ticket) do
    LedgerV2::Ticket.create!(
      canonical_key: "ledger_v2:phase_d:spec",
      title: "Phase D execution spec",
      status: :open,
      severity: :medium,
      review_status: :not_required,
      human_decision: :none
    )
  end
  let(:artifact) do
    LedgerV2::Artifact.create!(
      artifact_type: "ci_fix_suggestion",
      title: "CI 修正案",
      body: "phase d execution",
      format: "markdown",
      review_status: :accepted,
      run: run,
      related_ticket: ticket,
      metadata_json: {
        "draft_pr" => {
          "number" => 123,
          "head_sha" => "abc123",
          "ci_terminal" => true,
          "ci_terminal_reason" => "ci_passed"
        }
      }
    )
  end

  describe ".call" do
    it "auto_merge が無効なら gate に従って blocked を記録する" do
      allow(LedgerV2::Flags).to receive(:enabled?).with(:auto_merge).and_return(false)
      allow(LedgerV2::Flags).to receive(:enabled?).with(:auto_deploy).and_return(true)
      allow(GithubPrService).to receive(:merge_pr)

      expect {
        described_class.call(run: run, artifact: artifact)
      }.to change {
        LedgerV2::Event.where(event_type: "phase_d_execution_blocked").count
      }.by(1)

      expect(GithubPrService).not_to have_received(:merge_pr)
      expect(artifact.reload.metadata_json.dig("phase_d", "merge_block_reasons")).to include("auto_merge_disabled")
    end

    it "auto_deploy が無効なら merge せず blocked を記録する" do
      allow(LedgerV2::Flags).to receive(:enabled?).with(:auto_deploy).and_return(false)
      allow(LedgerV2::Flags).to receive(:enabled?).with(:auto_merge).and_return(true)
      allow(GithubPrService).to receive(:merge_pr)

      expect {
        described_class.call(run: run, artifact: artifact)
      }.to change {
        LedgerV2::Event.where(event_type: "phase_d_execution_blocked").count
      }.by(1)

      expect(GithubPrService).not_to have_received(:merge_pr)
      phase_d = artifact.reload.metadata_json.fetch("phase_d")
      expect(phase_d["execution_status"]).to eq("blocked")
      expect(phase_d["merge_allowed"]).to be true
      expect(phase_d["deploy_allowed"]).to be false
      expect(phase_d["deploy_block_reasons"]).to include("auto_deploy_disabled")
    end

    it "deploy_allowed なら draft PR を merge する" do
      allow(LedgerV2::Flags).to receive(:enabled?).with(:auto_deploy).and_return(true)
      allow(LedgerV2::Flags).to receive(:enabled?).with(:auto_merge).and_return(true)
      allow(GithubPrService).to receive(:merge_pr).and_return(
        { "merged" => true, "sha" => "merge123", "message" => "Pull Request successfully merged" }
      )

      expect {
        described_class.call(run: run, artifact: artifact)
      }.to change {
        LedgerV2::Event.where(event_type: "phase_d_pr_merged").count
      }.by(1)

      expect(GithubPrService).to have_received(:merge_pr).with(
        pr_number: 123,
        sha: "abc123",
        commit_title: "ledger-v2: merge Artifact ##{artifact.id}"
      )

      phase_d = artifact.reload.metadata_json.fetch("phase_d")
      expect(phase_d["execution_status"]).to eq("merged")
      expect(phase_d["merge_commit_sha"]).to eq("merge123")
      expect(phase_d["deploy_allowed"]).to be true
    end

    it "同じ merged 状態は重複記録しない" do
      artifact.update!(
        metadata_json: artifact.metadata_json.merge(
          "phase_d" => { "execution_status" => "merged", "merge_commit_sha" => "merge123" }
        )
      )
      allow(GithubPrService).to receive(:merge_pr)

      expect {
        described_class.call(run: run, artifact: artifact)
      }.not_to change(LedgerV2::Event, :count)

      expect(GithubPrService).not_to have_received(:merge_pr)
    end
  end
end
