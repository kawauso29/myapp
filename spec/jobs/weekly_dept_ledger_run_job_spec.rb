require "rails_helper"

RSpec.describe WeeklyDeptLedgerRunJob, type: :job do
  describe "#perform" do
    it "calls weekly runner" do
      allow(Ledgers::WeeklyDeptRunner).to receive(:call)

      described_class.perform_now(service_id: "ai_sns")

      expect(Ledgers::WeeklyDeptRunner).to have_received(:call).with(service_id: "ai_sns", ticket_inputs: nil)
    end
  end
end
