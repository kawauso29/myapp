require "rails_helper"

RSpec.describe QuarterlyReviewLedgerRunJob, type: :job do
  describe "#perform" do
    it "calls quarterly review runner" do
      allow(Ledgers::QuarterlyReviewRunner).to receive(:call)

      described_class.perform_now

      expect(Ledgers::QuarterlyReviewRunner).to have_received(:call)
    end
  end
end
