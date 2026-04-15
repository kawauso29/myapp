require "rails_helper"

RSpec.describe KpiLedger, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:kpi_key) }
    it { is_expected.to validate_presence_of(:scope_level) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:status) }

    it "validates uniqueness of kpi_key" do
      described_class.create!(kpi_key: "kpi:ai_sns_wau", scope_level: :service, service_id: "ai_sns", name: "WAU", status: :active)
      duplicate = described_class.new(kpi_key: "kpi:ai_sns_wau", scope_level: :service, service_id: "ai_sns", name: "WAU duplicate", status: :active)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:kpi_key]).to include("has already been taken")
    end
  end

  describe "enums" do
    it "defines scope_level enum" do
      expect(described_class.scope_levels.keys).to contain_exactly("company", "portfolio", "service", "cross_service")
    end
  end
end
