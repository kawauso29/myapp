require "rails_helper"

RSpec.describe Stops::ConditionEvaluator do
  describe "#call" do
    it "creates a kpi_breach stop when a KPI grade=critical exists" do
      create(:kpi_ledger,
             service_id: "ai_sns",
             kpi_key: "wau",
             status: :active,
             grade: :critical,
             current_value: { "value" => 10 },
             thresholds: { "healthy" => 100, "warning" => 50 })

      result = described_class.call(scope_level: :service, service_id: "ai_sns")

      expect(result.created.size).to eq(1)
      stop = result.created.first
      expect(stop).to be_trigger_type_kpi_breach
      expect(stop.service_id).to eq("ai_sns")
      expect(stop.evidence).to include("kpi_key" => "wau")
    end

    it "is idempotent within the same day" do
      create(:kpi_ledger,
             service_id: "ai_sns",
             kpi_key: "wau",
             status: :active,
             grade: :critical,
             current_value: { "value" => 10 },
             thresholds: { "healthy" => 100, "warning" => 50 })

      described_class.call(scope_level: :service, service_id: "ai_sns")
      second = described_class.call(scope_level: :service, service_id: "ai_sns")

      expect(second.created).to be_empty
      expect(StopLedger.where(trigger_type: StopLedger.trigger_types[:kpi_breach]).count).to eq(1)
    end

    it "does not create a stop for healthy KPIs" do
      create(:kpi_ledger,
             service_id: "ai_sns",
             kpi_key: "wau",
             status: :active,
             grade: :healthy,
             current_value: { "value" => 120 },
             thresholds: { "healthy" => 100, "warning" => 50 })

      result = described_class.call(scope_level: :service, service_id: "ai_sns")
      expect(result.created).to be_empty
    end

    it "records a manual_escalation stop when OperatorOverrideLedger has an active halt_service" do
      OperatorOverrideLedger.create!(
        action: :halt_service,
        scope_level: :service,
        service_id: "ai_sns",
        operator: "op1",
        reason: "manual kill switch",
        started_at: 1.hour.ago
      )

      result = described_class.call(scope_level: :service, service_id: "ai_sns")

      expect(result.created.size).to eq(1)
      stop = result.created.first
      expect(stop).to be_trigger_type_manual_escalation
      expect(stop.service_id).to eq("ai_sns")
    end

    it "is idempotent for manual_escalation within the same day" do
      OperatorOverrideLedger.create!(
        action: :halt_service,
        scope_level: :service,
        service_id: "ai_sns",
        operator: "op1",
        reason: "manual kill switch",
        started_at: 1.hour.ago
      )

      described_class.call(scope_level: :service, service_id: "ai_sns")
      second = described_class.call(scope_level: :service, service_id: "ai_sns")

      expect(second.created).to be_empty
      expect(StopLedger.where(trigger_type: StopLedger.trigger_types[:manual_escalation]).count).to eq(1)
    end

    it "creates a cost_runaway stop when monthly cost exceeds the threshold" do
      ENV["COST_RUNAWAY_MONTHLY_JPY"] = "1000"
      CostLedger.create!(
        subject_type: :job,
        subject_id: "job1",
        scope_level: :service,
        service_id: "ai_sns",
        amount_jpy: 5000,
        source: :llm_api,
        incurred_at: Time.current
      )

      result = described_class.call(scope_level: :service, service_id: "ai_sns")

      expect(result.created.size).to eq(1)
      stop = result.created.first
      expect(stop).to be_trigger_type_cost_runaway
      expect(stop.evidence["monthly_total_jpy"].to_f).to be >= 5000.0
    ensure
      ENV.delete("COST_RUNAWAY_MONTHLY_JPY")
    end

    it "does not create cost_runaway when monthly cost is under threshold" do
      ENV["COST_RUNAWAY_MONTHLY_JPY"] = "10000"
      CostLedger.create!(
        subject_type: :job,
        subject_id: "job1",
        scope_level: :service,
        service_id: "ai_sns",
        amount_jpy: 100,
        source: :llm_api,
        incurred_at: Time.current
      )

      result = described_class.call(scope_level: :service, service_id: "ai_sns")

      expect(result.created.select { |s| s.trigger_type == "cost_runaway" }).to be_empty
    ensure
      ENV.delete("COST_RUNAWAY_MONTHLY_JPY")
    end
  end
end
