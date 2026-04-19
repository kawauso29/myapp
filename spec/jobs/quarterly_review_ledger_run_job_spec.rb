require "rails_helper"

RSpec.describe QuarterlyReviewLedgerRunJob, type: :job do
  describe "#perform" do
    let(:meeting) { instance_double(MeetingLedger) }
    let(:payload) { { "operation" => "quarterly_review" } }

    it "calls quarterly review runner and notifies slack" do
      allow(Ledgers::QuarterlyReviewRunner).to receive(:call).and_return(meeting)
      allow(Ledgers::RunOutputFormatter).to receive(:format).and_return(payload.to_json)
      allow(Ledgers::SlackNotifier).to receive(:notify)

      described_class.perform_now

      expect(Ledgers::QuarterlyReviewRunner).to have_received(:call)
      expect(Ledgers::RunOutputFormatter).to have_received(:format).with(meeting:, operation: "quarterly_review")
      expect(Ledgers::SlackNotifier).to have_received(:notify).with(payload)
    end
  end
end
