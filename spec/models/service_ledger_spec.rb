require "rails_helper"

RSpec.describe ServiceLedger, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:service_id) }
    it { is_expected.to validate_presence_of(:scope_level) }
    it { is_expected.to validate_presence_of(:business_owner) }
    it { is_expected.to validate_presence_of(:status) }

    it "validates uniqueness of service_id" do
      described_class.create!(service_id: "ai_sns", scope_level: :service, business_owner: "owner", status: :active)
      duplicate = described_class.new(service_id: "ai_sns", scope_level: :service, business_owner: "owner2", status: :active)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:service_id]).to include("has already been taken")
    end
  end

  describe "enums" do
    it "defines scope_level enum" do
      expect(described_class.scope_levels.keys).to contain_exactly("company", "portfolio", "service", "cross_service")
    end
  end
end
