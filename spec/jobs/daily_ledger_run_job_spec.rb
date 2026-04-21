require "rails_helper"

RSpec.describe DailyLedgerRunJob do
  describe "#perform" do
    let!(:daily_definition) do
      MeetingDefinition.find_or_create_by!(meeting_key: "daily") do |d|
        d.meeting_type = :daily
        d.scope_level = :service
        d.service_id = "ai_sns"
        d.chair_role = "system"
        d.participant_roles = []
      end
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
