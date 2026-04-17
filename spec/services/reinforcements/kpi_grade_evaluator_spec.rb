require "rails_helper"

RSpec.describe Reinforcements::KpiGradeEvaluator do
  describe ".call" do
    it "evaluates active KPIs with thresholds and skips those without" do
      create(:kpi_ledger,
             kpi_key: "kpi:with_thresholds_healthy",
             current_value: { "value" => 200 },
             thresholds: { "healthy" => 100, "warning" => 50 })
      create(:kpi_ledger,
             kpi_key: "kpi:with_thresholds_no_value",
             current_value: {},
             thresholds: { "healthy" => 100, "warning" => 50 })
      create(:kpi_ledger, kpi_key: "kpi:no_thresholds", current_value: { "value" => 50 }, thresholds: {})

      result = described_class.call

      expect(result[:evaluated]).to eq(1)
      expect(result[:skipped]).to eq(1)
      expect(result[:details]).to contain_exactly(hash_including(kpi_key: "kpi:with_thresholds_healthy", grade: "healthy"))
      expect(KpiLedger.find_by(kpi_key: "kpi:with_thresholds_healthy").grade).to eq("healthy")
    end

    it "skips paused KPIs" do
      create(:kpi_ledger,
             kpi_key: "kpi:paused",
             status: :paused,
             current_value: { "value" => 200 },
             thresholds: { "healthy" => 100, "warning" => 50 })

      result = described_class.call

      expect(result[:evaluated]).to eq(0)
    end

    it "returns error hash on failure without raising" do
      allow(KpiLedger).to receive(:status_active).and_raise(StandardError.new("boom"))

      result = described_class.call

      expect(result[:error]).to eq("boom")
      expect(result[:evaluated]).to eq(0)
    end
  end
end
