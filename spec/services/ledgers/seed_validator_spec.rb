require "rails_helper"

RSpec.describe Ledgers::SeedValidator do
  describe ".call" do
    it "returns ok when all required records exist" do
      Ledgers::SeedValidator::REQUIRED_MEETING_KEYS.each do |key|
        create(:meeting_definition, meeting_key: key, meeting_type: :monthly)
      end
      Ledgers::SeedValidator::REQUIRED_SERVICE_IDS.each do |sid|
        create(:service_ledger, service_id: sid)
      end
      Ledgers::SeedValidator::REQUIRED_KPI_KEYS.each do |key|
        create(:kpi_ledger, kpi_key: key)
      end
      Ledgers::SeedValidator::REQUIRED_LANE_CAPS.each do |lane|
        create(:lane_capacity_cap, scope_level: :service, service_id: "ai_sns",
                                   operating_lane: lane.to_sym, wip_cap: 3)
      end

      result = described_class.call

      expect(result).to be_ok
      expect(result.errors_text).to be_blank
    end

    it "reports missing meeting_definitions" do
      result = described_class.call

      expect(result).not_to be_ok
      expect(result.missing[:meeting_definitions]).to match_array(Ledgers::SeedValidator::REQUIRED_MEETING_KEYS)
    end

    it "reports missing kpi_ledgers when some are absent" do
      Ledgers::SeedValidator::REQUIRED_MEETING_KEYS.each do |key|
        create(:meeting_definition, meeting_key: key, meeting_type: :monthly)
      end
      Ledgers::SeedValidator::REQUIRED_SERVICE_IDS.each do |sid|
        create(:service_ledger, service_id: sid)
      end
      create(:kpi_ledger, kpi_key: Ledgers::SeedValidator::REQUIRED_KPI_KEYS.first)

      result = described_class.call

      expect(result).not_to be_ok
      expect(result.missing[:kpi_ledgers]).to include(Ledgers::SeedValidator::REQUIRED_KPI_KEYS.last)
    end

    it "errors_text includes human-readable category and keys" do
      result = described_class.call

      text = result.errors_text
      expect(text).to include("meeting_definitions")
      expect(text).to include("weekly_dept")
    end

    it "reports missing lane_capacity_caps (Phase 2 補強 / 穴⑤)" do
      Ledgers::SeedValidator::REQUIRED_MEETING_KEYS.each do |key|
        create(:meeting_definition, meeting_key: key, meeting_type: :monthly)
      end
      Ledgers::SeedValidator::REQUIRED_SERVICE_IDS.each do |sid|
        create(:service_ledger, service_id: sid)
      end
      Ledgers::SeedValidator::REQUIRED_KPI_KEYS.each do |key|
        create(:kpi_ledger, kpi_key: key)
      end
      # only seed one lane cap; the rest should be reported as missing
      create(:lane_capacity_cap, scope_level: :service, service_id: "ai_sns",
                                 operating_lane: :immediate, wip_cap: 3)

      result = described_class.call

      expect(result).not_to be_ok
      expect(result.missing[:lane_capacity_caps]).to match_array(
        Ledgers::SeedValidator::REQUIRED_LANE_CAPS - [ "immediate" ]
      )
    end
  end
end
