require "rails_helper"

RSpec.describe WeeklyDeptLedgerRunJob, type: :job do
  describe "#perform" do
    let(:meeting) { instance_double(MeetingLedger) }
    let(:payload) { { "operation" => "weekly_dept" } }

    it "calls weekly runner and notifies slack" do
      allow(Ledgers::WeeklyDeptRunner).to receive(:call).and_return(meeting)
      allow(Ledgers::RunOutputFormatter).to receive(:format).and_return(payload.to_json)
      allow(Ledgers::SlackNotifier).to receive(:notify)

      described_class.perform_now(service_id: "ai_sns")

      expect(Ledgers::WeeklyDeptRunner).to have_received(:call).with(service_id: "ai_sns", ticket_inputs: nil)
      expect(Ledgers::RunOutputFormatter).to have_received(:format).with(meeting:, operation: "weekly_dept")
      expect(Ledgers::SlackNotifier).to have_received(:notify).with(payload)
    end
  end
end
