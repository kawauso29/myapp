require "rails_helper"

RSpec.describe MeetingDefinition, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:meeting_key) }
    it { is_expected.to validate_presence_of(:meeting_type) }
    it { is_expected.to validate_presence_of(:scope_level) }
    it { is_expected.to validate_presence_of(:chair_role) }
  end

  describe "enums" do
    it "defines meeting_type enum" do
      expect(described_class.meeting_types.keys).to contain_exactly(
        "long_term",
        "annual",
        "quarterly",
        "monthly",
        "weekly",
        "incident",
        "quarterly_review",
        "annual_plan"
      )
    end

    it "defines scope_level enum" do
      expect(described_class.scope_levels.keys).to contain_exactly("company", "portfolio", "service", "cross_service")
    end
  end
end
