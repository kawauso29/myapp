require "rails_helper"

RSpec.describe MonthlyOpsLedgerRunJob, type: :job do
  describe "#perform" do
    let(:meeting) { instance_double(MeetingLedger) }
    let(:payload) { { "operation" => "monthly_ops" } }

    it "calls monthly runner and notifies slack" do
      allow(Ledgers::MonthlyOpsRunner).to receive(:call).and_return(meeting)
      allow(Ledgers::RunOutputFormatter).to receive(:format).and_return(payload.to_json)
      allow(Ledgers::SlackNotifier).to receive(:notify)

      described_class.perform_now(resolution_map: { 1 => "approved" })

      expect(Ledgers::MonthlyOpsRunner).to have_received(:call).with(resolution_map: { 1 => "approved" })
      expect(Ledgers::RunOutputFormatter).to have_received(:format).with(meeting:, operation: "monthly_ops")
      expect(Ledgers::SlackNotifier).to have_received(:notify).with(payload)
    end
  end
end
