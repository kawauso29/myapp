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
end
