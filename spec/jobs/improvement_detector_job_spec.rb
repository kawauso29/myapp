require "rails_helper"

RSpec.describe ImprovementDetectorJob, type: :job do
  describe "#perform" do
    it "calls detector and resolver" do
      allow(Ledgers::ImprovementDetector).to receive(:call).and_return({ detected: 2, details: [] })

      result = described_class.perform_now

      expect(Ledgers::ImprovementDetector).to have_received(:call)
      expect(result).to eq(detected: 2)
    end
  end
end
