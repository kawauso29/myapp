require "rails_helper"

RSpec.describe PortfolioRebalanceRunJob, type: :job do
  before { Rails.cache.clear }

  describe "#perform" do
    it "invokes Portfolio::Rebalancer" do
      expect(Portfolio::Rebalancer).to receive(:call).and_call_original

      described_class.perform_now
    end
  end
end
