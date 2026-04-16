require "rails_helper"

RSpec.describe ImprovementEscalationJob, type: :job do
  describe "#perform" do
    it "calls improvement escalator" do
      result = { operation: "escalate_improvements", overdue_marked: 0, escalated_monthly: 0, escalated_quarterly: 0, details: [] }
      allow(Ledgers::ImprovementEscalator).to receive(:call).and_return(result)

      expect(described_class.perform_now).to eq(result)
      expect(Ledgers::ImprovementEscalator).to have_received(:call)
    end
  end
end
