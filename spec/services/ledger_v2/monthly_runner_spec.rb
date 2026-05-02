require "rails_helper"

RSpec.describe LedgerV2::MonthlyRunner, type: :service do
  let(:run) { LedgerV2::Run.create!(runner_name: "MonthlyRunner", trigger_type: :manual, dry_run: true) }

  def model_counts
    [
      LedgerV2::Artifact.count,
      LedgerV2::Event.count,
      LedgerV2::Ticket.count
    ]
  end

  describe ".call" do
    it "dry_run: true で RunnerResult を返す" do
      result = described_class.call(run: run, dry_run: true)

      expect(result).to be_a(LedgerV2::RunExecutor::RunnerResult)
      expect(result.created_ticket_count).to eq(0)
      expect(result.updated_ticket_count).to eq(0)
      expect(result.created_artifact_count).to eq(0)
      expect(result.created_event_count).to eq(0)
      expect(result.duplicate_prevented_count).to eq(0)
    end

    it "dry_run: true では Artifact / Event / Ticket を作成しない" do
      before_counts = model_counts

      described_class.call(run: run, dry_run: true)

      expect(model_counts).to eq(before_counts)
    end

    it "dry_run: true で Weekly Artifact を月次 draft 生成サービスへ渡す" do
      weekly_artifact = LedgerV2::Artifact.create!(
        artifact_type: "weekly_review",
        title: "週次レビュー W18",
        body: "weekly body",
        review_status: :pending
      )
      allow(LedgerV2::BuildMonthlyArtifact).to receive(:call).and_call_original

      described_class.call(run: run, dry_run: true)

      expect(LedgerV2::BuildMonthlyArtifact).to have_received(:call).with(
        run:,
        weekly_artifacts: [weekly_artifact],
        active_tickets: []
      )
    end

    it "dry_run: false は許可しない" do
      expect {
        described_class.call(run: run, dry_run: false)
      }.to raise_error(ArgumentError, /dry_run: true/)
    end
  end
end
