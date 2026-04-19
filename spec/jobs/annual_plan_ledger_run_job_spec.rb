require "rails_helper"

RSpec.describe AnnualPlanLedgerRunJob, type: :job do
  describe "#perform" do
    let(:meeting) { instance_double(MeetingLedger) }
    let(:payload) { { "operation" => "annual_plan" } }

    it "calls annual plan runner and notifies slack" do
      allow(Ledgers::AnnualPlanRunner).to receive(:call).and_return(meeting)
      allow(Ledgers::RunOutputFormatter).to receive(:format).and_return(payload.to_json)
      allow(Ledgers::SlackNotifier).to receive(:notify)

      described_class.perform_now

      expect(Ledgers::AnnualPlanRunner).to have_received(:call)
      expect(Ledgers::RunOutputFormatter).to have_received(:format).with(meeting:, operation: "annual_plan")
      expect(Ledgers::SlackNotifier).to have_received(:notify).with(payload)
    end
  end
end
