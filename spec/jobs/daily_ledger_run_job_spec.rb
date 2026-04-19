require "rails_helper"

RSpec.describe DailyLedgerRunJob do
  describe "#perform" do
    let!(:daily_definition) do
      create(:meeting_definition,
             meeting_key: "daily",
             meeting_type: :daily,
             scope_level: :service,
             service_id: "ai_sns",
             chair_role: "system",
             participant_roles: [])
    end

    before do
      allow(Ledgers::SlackNotifier).to receive(:notify)
    end

    it "creates a daily meeting via DailyRunner" do
      meeting = described_class.new.perform("ai_sns")

      expect(meeting).to be_persisted
      expect(meeting).to be_meeting_type_daily
    end

    it "notifies Slack with formatted output" do
      described_class.new.perform("ai_sns")

      expect(Ledgers::SlackNotifier).to have_received(:notify)
    end
  end
end
