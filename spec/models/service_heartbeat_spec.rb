require "rails_helper"

RSpec.describe ServiceHeartbeat, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:meeting_definition) }
    it { is_expected.to validate_presence_of(:due_cycle) }
    it { is_expected.to validate_presence_of(:status) }
  end

  describe "enums" do
    it "defines due_cycle enum" do
      expect(described_class.due_cycles.keys).to include("weekly", "monthly")
    end
  end
end
