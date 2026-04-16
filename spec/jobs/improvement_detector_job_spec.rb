require "rails_helper"

RSpec.describe ImprovementDetectorJob, type: :job do
  describe "#perform" do
    it "calls detector and notifies when tickets are created" do
      result = { created_tickets_count: 2, created_tickets: [ { id: 1, rule: "overdue_rate" } ] }
      allow(Ledgers::ImprovementDetector).to receive(:call).and_return(result)
      allow(Ledgers::SlackNotifier).to receive(:notify)

      described_class.perform_now

      expect(Ledgers::ImprovementDetector).to have_received(:call)
      expect(Ledgers::SlackNotifier).to have_received(:notify).with(
        hash_including(operation: "detect_improvements")
      )
    end

    it "does not notify when nothing is created" do
      allow(Ledgers::ImprovementDetector).to receive(:call).and_return(created_tickets_count: 0, created_tickets: [])
      allow(Ledgers::SlackNotifier).to receive(:notify)

      described_class.perform_now

      expect(Ledgers::SlackNotifier).not_to have_received(:notify)
    end
  end
end
