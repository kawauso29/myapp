require "rails_helper"

RSpec.describe Reinforcements::MeetingHealthScorer do
  describe ".score!" do
    it "persists computed health score for a complete meeting" do
      meeting = create(:meeting_ledger,
                       role_fill_rate: 1.0,
                       hold_item_rate: 0.0,
                       kpi_correlation_score: 1.0,
                       duration_minutes: 60)
      described_class.score!(meeting)
      expect(meeting.reload.meeting_health_score.to_f).to be_within(0.001).of(1.0)
    end

    it "does nothing when required metrics are missing" do
      meeting = create(:meeting_ledger, role_fill_rate: 1.0, hold_item_rate: nil)
      described_class.score!(meeting)
      expect(meeting.reload.meeting_health_score).to be_nil
    end
  end

  describe ".unhealthy_streak?" do
    let(:definition) { create(:meeting_definition, meeting_key: "weekly_dept") }

    it "returns true when the recent N meetings are all below threshold" do
      2.times do |i|
        create(:meeting_ledger,
               meeting_definition: definition,
               meeting_key: "weekly_dept",
               held_at: Time.current - i.days,
               meeting_health_score: 0.3)
      end
      expect(described_class.unhealthy_streak?(meeting_key: "weekly_dept", streak: 2)).to be true
    end

    it "returns false when not enough scored meetings exist" do
      create(:meeting_ledger,
             meeting_definition: definition,
             meeting_key: "weekly_dept",
             meeting_health_score: 0.3)
      expect(described_class.unhealthy_streak?(meeting_key: "weekly_dept", streak: 2)).to be false
    end

    it "returns false when any recent meeting is above threshold" do
      create(:meeting_ledger,
             meeting_definition: definition,
             meeting_key: "weekly_dept",
             held_at: 2.days.ago,
             meeting_health_score: 0.3)
      create(:meeting_ledger,
             meeting_definition: definition,
             meeting_key: "weekly_dept",
             held_at: 1.day.ago,
             meeting_health_score: 0.8)
      expect(described_class.unhealthy_streak?(meeting_key: "weekly_dept", streak: 2)).to be false
    end
  end
end
