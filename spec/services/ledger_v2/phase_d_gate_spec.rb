require "rails_helper"

RSpec.describe LedgerV2::PhaseDGate, type: :service do
  let(:run) { LedgerV2::Run.create!(runner_name: "PhaseDGateSpec", trigger_type: :manual) }
  let(:ticket) do
    LedgerV2::Ticket.create!(
      canonical_key: "ledger_v2:phase_d_gate:spec",
      title: "Phase D gate spec",
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
      body: "phase d gate test",
      format: "markdown",
      review_status: :accepted,
      run: run,
      related_ticket: ticket,
      metadata_json: metadata_json
    )
  end

  describe ".call" do
    context "draft PR が terminal ci_passed で auto_merge / auto_deploy が有効なとき" do
      let(:metadata_json) do
        {
          "draft_pr" => {
            "number" => 123,
            "ci_terminal" => true,
            "ci_terminal_reason" => "ci_passed"
          }
        }
      end

      before do
        allow(LedgerV2::Flags).to receive(:enabled?).with(:auto_merge).and_return(true)
        allow(LedgerV2::Flags).to receive(:enabled?).with(:auto_deploy).and_return(true)
      end

      it "merge/deploy ともに許可する" do
        result = described_class.call(artifact: artifact)

        expect(result.merge_allowed).to be true
        expect(result.deploy_allowed).to be true
        expect(result.merge_block_reasons).to eq([])
        expect(result.deploy_block_reasons).to eq([])
      end
    end

    context "CI が terminal でないとき" do
      let(:metadata_json) do
        {
          "draft_pr" => {
            "number" => 123,
            "ci_terminal" => false,
            "ci_terminal_reason" => nil
          }
        }
      end

      before do
        allow(LedgerV2::Flags).to receive(:enabled?).with(:auto_merge).and_return(true)
        allow(LedgerV2::Flags).to receive(:enabled?).with(:auto_deploy).and_return(true)
      end

      it "merge/deploy を不許可にし理由を返す" do
        result = described_class.call(artifact: artifact)

        expect(result.merge_allowed).to be false
        expect(result.deploy_allowed).to be false
        expect(result.merge_block_reasons).to include("ci_not_terminal", "ci_not_passed")
        expect(result.deploy_block_reasons).to include("ci_not_terminal", "ci_not_passed")
      end
    end

    context "auto_deploy が無効なとき" do
      let(:metadata_json) do
        {
          "draft_pr" => {
            "number" => 123,
            "ci_terminal" => true,
            "ci_terminal_reason" => "ci_passed"
          }
        }
      end

      before do
        allow(LedgerV2::Flags).to receive(:enabled?).with(:auto_merge).and_return(true)
        allow(LedgerV2::Flags).to receive(:enabled?).with(:auto_deploy).and_return(false)
      end

      it "merge は許可し deploy だけ不許可にする" do
        result = described_class.call(artifact: artifact)

        expect(result.merge_allowed).to be true
        expect(result.deploy_allowed).to be false
        expect(result.merge_block_reasons).to eq([])
        expect(result.deploy_block_reasons).to include("auto_deploy_disabled")
      end
    end

    context "draft_pr が欠落しているとき" do
      let(:metadata_json) { {} }

      before do
        allow(LedgerV2::Flags).to receive(:enabled?).with(:auto_merge).and_return(true)
        allow(LedgerV2::Flags).to receive(:enabled?).with(:auto_deploy).and_return(true)
      end

      it "merge/deploy を不許可にする" do
        result = described_class.call(artifact: artifact)

        expect(result.merge_allowed).to be false
        expect(result.deploy_allowed).to be false
        expect(result.merge_block_reasons).to eq(["draft_pr_missing"])
        expect(result.deploy_block_reasons).to eq(["draft_pr_missing"])
      end
    end
  end
end
