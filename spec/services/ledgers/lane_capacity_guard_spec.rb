require "rails_helper"

RSpec.describe Ledgers::LaneCapacityGuard do
  describe ".allowed?" do
    it "returns true when no cap is configured" do
      expect(described_class.allowed?(operating_lane: :weekly_improvement, service_id: "ai_sns")).to be(true)
    end

    it "returns true when current_usage < cap" do
      create(:lane_capacity_cap,
             scope_level: :service,
             service_id: "ai_sns",
             operating_lane: :weekly_improvement,
             wip_cap: 3)
      # 2 existing in-flight tickets
      2.times do
        create(:ticket_ledger, operating_lane: :weekly_improvement, status: :approved, service_id: "ai_sns")
      end

      expect(described_class.allowed?(operating_lane: :weekly_improvement, service_id: "ai_sns")).to be(true)
    end

    it "returns false when current_usage >= cap" do
      create(:lane_capacity_cap,
             scope_level: :service,
             service_id: "ai_sns",
             operating_lane: :weekly_improvement,
             wip_cap: 2)
      2.times do
        create(:ticket_ledger, operating_lane: :weekly_improvement, status: :approved, service_id: "ai_sns")
      end

      expect(described_class.allowed?(operating_lane: :weekly_improvement, service_id: "ai_sns")).to be(false)
    end

    it "ignores completed tickets when counting usage" do
      create(:lane_capacity_cap,
             scope_level: :service,
             service_id: "ai_sns",
             operating_lane: :weekly_improvement,
             wip_cap: 1)
      create(:ticket_ledger, operating_lane: :weekly_improvement, status: :completed, service_id: "ai_sns")

      expect(described_class.allowed?(operating_lane: :weekly_improvement, service_id: "ai_sns")).to be(true)
    end
  end
end
