require "rails_helper"

RSpec.describe LedgerV2::RecordPhaseDDeploy, type: :service do
  let(:run) { LedgerV2::Run.create!(runner_name: "SyncDraftPrStatus", trigger_type: :schedule) }
  let(:ticket) do
    LedgerV2::Ticket.create!(
      canonical_key: "ledger_v2:phase_d:deploy:spec",
      title: "Phase D deploy recording spec",
      status: :open,
      severity: :medium,
      review_status: :not_required,
      human_decision: :none
    )
  end
  let!(:artifact) do
    LedgerV2::Artifact.create!(
      artifact_type: "ci_fix_suggestion",
      title: "CI 修正案",
      body: "phase d deploy recording",
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
        },
        "phase_d" => {
          "execution_status" => "merged",
          "merge_commit_sha" => "merge123"
        }
      }
    )
  end

  describe ".call" do
    it "deploy failure と rollback success を metadata と Event に記録する" do
      expect {
        result = described_class.call(
          commit_sha: "merge123",
          deploy_status: "failed",
          rollback_status: "succeeded",
          rollback_target_sha: "prev123",
          failed_stage: "health_check",
          workflow_run_id: "999",
          workflow_url: "https://example.com/actions/runs/999",
          deploy_reason: "Auto-deploy after CI pass on main: merge123",
          actor: "github-actions[bot]"
        )

        expect(result.created_event_count).to eq(2)
      }.to change {
        LedgerV2::Event.where(event_type: "phase_d_deploy_failed").count
      }.by(1).and change {
        LedgerV2::Event.where(event_type: "phase_d_rollback_succeeded").count
      }.by(1)

      deployment = artifact.reload.metadata_json.dig("phase_d", "deployment")
      expect(deployment["commit_sha"]).to eq("merge123")
      expect(deployment["status"]).to eq("failed")
      expect(deployment["failed_stage"]).to eq("health_check")
      expect(deployment["workflow_run_id"]).to eq("999")
      expect(deployment["workflow_url"]).to eq("https://example.com/actions/runs/999")
      expect(deployment["reason"]).to eq("Auto-deploy after CI pass on main: merge123")
      expect(deployment["actor"]).to eq("github-actions[bot]")
      expect(deployment.dig("rollback", "status")).to eq("succeeded")
      expect(deployment.dig("rollback", "target_sha")).to eq("prev123")
    end
  end
end
