require "rails_helper"

RSpec.describe ImprovementResolverJob, type: :job do
  describe "#perform" do
    it "calls resolver and notifies when tickets are resolved" do
      result = { resolved: 1, details: [ { ticket_id: 1, rule: "high_overdue_rate", title: "A" } ] }
      allow(Ledgers::ImprovementResolver).to receive(:call).and_return(result)
      allow(Ledgers::SlackNotifier).to receive(:notify)

      described_class.perform_now

      expect(Ledgers::ImprovementResolver).to have_received(:call)
      expect(Ledgers::SlackNotifier).to have_received(:notify).with(
        hash_including(operation: "resolve_improvements")
      )
    end

    it "does not notify when nothing is resolved" do
      allow(Ledgers::ImprovementResolver).to receive(:call).and_return(resolved: 0, details: [])
      allow(Ledgers::SlackNotifier).to receive(:notify)

      described_class.perform_now

      expect(Ledgers::SlackNotifier).not_to have_received(:notify)
    end
  end
end
