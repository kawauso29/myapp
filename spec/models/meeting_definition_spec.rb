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
        "annual_plan",
        "daily"
      )
    end

    it "defines scope_level enum" do
      expect(described_class.scope_levels.keys).to contain_exactly("company", "portfolio", "service", "cross_service")
    end
  end

  describe "R1: allowed_cycles" do
    it "accepts valid cycles" do
      definition = build(:meeting_definition, allowed_cycles: %w[daily weekly])
      expect(definition).to be_valid
    end

    it "rejects invalid cycles" do
      definition = build(:meeting_definition, allowed_cycles: %w[hourly])
      expect(definition).not_to be_valid
      expect(definition.errors[:allowed_cycles]).to be_present
    end

    it "allows empty array (backward compatible: all cycles allowed)" do
      definition = build(:meeting_definition, allowed_cycles: [])
      expect(definition).to be_valid
    end
  end

  describe "#cycle_allowed?" do
    it "returns true when allowed_cycles is empty" do
      definition = build(:meeting_definition, allowed_cycles: [])
      expect(definition.cycle_allowed?(:daily)).to be true
    end

    it "returns true for allowed cycle" do
      definition = build(:meeting_definition, allowed_cycles: %w[daily weekly])
      expect(definition.cycle_allowed?("weekly")).to be true
    end

    it "returns false for disallowed cycle" do
      definition = build(:meeting_definition, allowed_cycles: %w[daily weekly])
      expect(definition.cycle_allowed?("monthly")).to be false
    end
  end

  describe "backward compatibility without allowed_cycles column" do
    before do
      names_without_allowed_cycles = described_class.attribute_names - ["allowed_cycles"]
      allow(described_class).to receive(:attribute_names).and_return(names_without_allowed_cycles)
    end

    it "does not raise on validation" do
      definition = build(:meeting_definition)
      expect { definition.valid? }.not_to raise_error
      expect(definition).to be_valid
    end

    it "treats cycles as allowed" do
      definition = build(:meeting_definition)
      expect(definition.cycle_allowed?(:daily)).to be true
    end
  end
end
