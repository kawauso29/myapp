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
  end
end
