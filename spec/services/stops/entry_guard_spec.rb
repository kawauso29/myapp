require "rails_helper"

RSpec.describe Stops::EntryGuard do
  let(:ticket) { create(:ticket_ledger) } # for belongs_to target; not used for guard

  def create_stop(attrs)
    create(:stop_ledger, { trigger_type: :kpi_breach, trigger_detail: "test", status: :active, started_at: 1.hour.ago, evidence: {} }.merge(attrs))
  end

  describe ".check" do
    it "allows when no active stops exist" do
      result = described_class.check(scope_level: :service, service_id: "ai_sns")
      expect(result.allowed?).to be true
      expect(result.active_stops).to be_empty
    end

    it "blocks service-scope tickets when a service stop is active for the same service_id" do
      stop = create_stop(scope_level: :service, service_id: "ai_sns")

      result = described_class.check(scope_level: :service, service_id: "ai_sns")

      expect(result.allowed?).to be false
      expect(result.active_stops).to include(stop)
    end

    it "does NOT block service tickets when service stop is for a different service_id" do
      create_stop(scope_level: :service, service_id: "other_svc")

      result = described_class.check(scope_level: :service, service_id: "ai_sns")
      expect(result.allowed?).to be true
    end

    it "blocks service tickets when a company-scope stop is active" do
      stop = create_stop(scope_level: :company, service_id: nil)

      result = described_class.check(scope_level: :service, service_id: "ai_sns")
      expect(result.allowed?).to be false
      expect(result.active_stops).to include(stop)
    end

    it "does not block lifted stops" do
      create_stop(scope_level: :service, service_id: "ai_sns", status: :lifted, lifted_at: 10.minutes.ago, lifted_by: "ops", lift_reason: "ok")

      result = described_class.check(scope_level: :service, service_id: "ai_sns")
      expect(result.allowed?).to be true
    end

    it "blocks cross_service tickets for cross_service stop" do
      stop = create_stop(scope_level: :cross_service, service_id: nil)

      result = described_class.check(scope_level: :service, service_id: "ai_sns")
      expect(result.allowed?).to be false
      expect(result.active_stops).to include(stop)
    end
  end

  describe ".assert!" do
    it "raises Blocked when active stop exists" do
      create_stop(scope_level: :service, service_id: "ai_sns")

      expect {
        described_class.assert!(scope_level: :service, service_id: "ai_sns")
      }.to raise_error(described_class::Blocked, /blocked by active stops/)
    end

    it "returns true when no active stop exists" do
      expect(described_class.assert!(scope_level: :service, service_id: "ai_sns")).to be true
    end
  end
end
