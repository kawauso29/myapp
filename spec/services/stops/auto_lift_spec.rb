require "rails_helper"

RSpec.describe Stops::ConditionEvaluator, "#lift_resolved!" do
  describe "kpi_breach auto-lift" do
    let!(:kpi) do
      create(:kpi_ledger, kpi_key: "kpi:wau", service_id: "ai_sns",
             status: :active, grade: :critical,
             current_value: { "value" => 10 },
             thresholds: { "healthy" => 100, "warning" => 50 })
    end

    it "lifts the active stop when KPI grade becomes healthy" do
      described_class.call(scope_level: :service, service_id: "ai_sns")
      expect(StopLedger.status_active.where(trigger_type: :kpi_breach).count).to eq(1)

      kpi.update!(grade: :healthy, current_value: { "value" => 150 })
      result = described_class.new(scope_level: :service, service_id: "ai_sns").lift_resolved!

      expect(result[:lifted].size).to eq(1)
      stop = result[:lifted].first
      expect(stop).to be_status_lifted
      expect(stop.lifted_by).to eq("system_auto_lifter")
      expect(stop.lift_reason).to include("kpi_grade_resolved")
    end

    it "does not lift while KPI grade is still critical" do
      described_class.call(scope_level: :service, service_id: "ai_sns")
      result = described_class.new(scope_level: :service, service_id: "ai_sns").lift_resolved!
      expect(result[:lifted]).to be_empty
    end
  end

  describe "manual_escalation auto-lift" do
    it "lifts when OperatorOverrideLedger halt is cleared" do
      override = OperatorOverrideLedger.create!(
        action: :halt_service, scope_level: :service, service_id: "ai_sns",
        operator: "op1", reason: "test", started_at: 1.hour.ago
      )
      described_class.call(scope_level: :service, service_id: "ai_sns")
      expect(StopLedger.status_active.where(trigger_type: :manual_escalation).count).to eq(1)

      override.update!(lifted_at: Time.current)

      result = described_class.new(scope_level: :service, service_id: "ai_sns").lift_resolved!
      expect(result[:lifted].size).to eq(1)
      expect(result[:lifted].first.lift_reason).to eq("operator_halt_cleared")
    end
  end

  describe "unknown trigger types" do
    it "skips lifting for trigger_types it does not recognise" do
      stop = StopLedger.create!(
        trigger_type: :cost_runaway, trigger_detail: "manual",
        scope_level: :service, service_id: "ai_sns",
        status: :active, started_at: 1.hour.ago, evidence: {}
      )
      # cost runaway: threshold ENV を巨大にすれば常に下回る
      ENV["COST_RUNAWAY_MONTHLY_JPY"] = "999999999999"

      result = described_class.new(scope_level: :service, service_id: "ai_sns").lift_resolved!
      expect(result[:lifted].map(&:id)).to include(stop.id)
    ensure
      ENV.delete("COST_RUNAWAY_MONTHLY_JPY")
    end
  end
end
