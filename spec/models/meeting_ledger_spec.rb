require "rails_helper"

RSpec.describe MeetingLedger, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:meeting_definition) }
    it { is_expected.to validate_presence_of(:meeting_key) }
    it { is_expected.to validate_presence_of(:meeting_type) }
    it { is_expected.to validate_presence_of(:scope_level) }
    it { is_expected.to validate_presence_of(:chair) }
    it { is_expected.to validate_presence_of(:held_at) }
    it { is_expected.to validate_presence_of(:status) }
  end

  describe "enums" do
    it "defines status enum" do
      expect(described_class.statuses.keys).to contain_exactly("open", "closed", "followup_pending")
    end
  end

  describe "補強15: health fields" do
    it "rejects role_fill_rate outside 0..1" do
      record = build(:meeting_ledger, role_fill_rate: 1.5)
      expect(record).not_to be_valid
      expect(record.errors[:role_fill_rate]).to be_present
    end

    it "rejects negative duration_minutes" do
      record = build(:meeting_ledger, duration_minutes: -1)
      expect(record).not_to be_valid
      expect(record.errors[:duration_minutes]).to be_present
    end

    describe "#compute_meeting_health_score" do
      it "returns nil when any of the three core metrics is missing" do
        record = build(:meeting_ledger, role_fill_rate: 1.0, hold_item_rate: nil, kpi_correlation_score: 1.0)
        expect(record.compute_meeting_health_score).to be_nil
      end

      it "returns 1.0 for an ideal meeting" do
        record = build(:meeting_ledger,
                       role_fill_rate: 1.0,
                       hold_item_rate: 0.0,
                       kpi_correlation_score: 1.0,
                       duration_minutes: 60)
        expect(record.compute_meeting_health_score).to be_within(0.001).of(1.0)
      end

      it "penalizes meetings that run much longer than 120 minutes" do
        record = build(:meeting_ledger,
                       role_fill_rate: 1.0,
                       hold_item_rate: 0.0,
                       kpi_correlation_score: 1.0,
                       duration_minutes: 240)
        expect(record.compute_meeting_health_score).to be < 1.0
      end
    end

    describe "#unhealthy?" do
      it "returns true when meeting_health_score is below threshold" do
        record = build(:meeting_ledger, meeting_health_score: 0.3)
        expect(record.unhealthy?).to be true
      end

      it "returns false when meeting_health_score is nil" do
        expect(build(:meeting_ledger, meeting_health_score: nil).unhealthy?).to be false
      end
    end
  end
end
