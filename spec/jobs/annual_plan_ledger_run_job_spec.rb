require "rails_helper"

RSpec.describe AnnualPlanLedgerRunJob, type: :job do
  describe "#perform" do
    it "calls annual plan runner" do
      allow(Ledgers::AnnualPlanRunner).to receive(:call)

      described_class.perform_now

      expect(Ledgers::AnnualPlanRunner).to have_received(:call)
    end
  end
end
