require "rails_helper"

RSpec.describe MonthlyOpsLedgerRunJob, type: :job do
  describe "#perform" do
    it "calls monthly runner" do
      allow(Ledgers::MonthlyOpsRunner).to receive(:call)

      described_class.perform_now(resolution_map: { 1 => "approved" })

      expect(Ledgers::MonthlyOpsRunner).to have_received(:call).with(resolution_map: { 1 => "approved" })
    end
  end
end
