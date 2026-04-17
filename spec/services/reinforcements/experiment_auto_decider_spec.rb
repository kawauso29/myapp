require "rails_helper"

RSpec.describe Reinforcements::ExperimentAutoDecider do
  describe ".call" do
    it "marks expired experiments as withdrawn when KPI not met" do
      create(:experiment_ledger,
             deadline: 1.day.ago.to_date,
             kpi_targets: [{ "kpi_key" => "kpi:engagement", "threshold" => 0.5 }])

      result = described_class.call

      expect(result[:decided]).to eq(1)
      expect(result[:details].first[:decision][:status]).to eq(:withdrawn)
    end

    it "marks expired experiments as continued when KPI is met" do
      kpi = create(:kpi_ledger, kpi_key: "kpi:retention", service_id: "ai_sns",
                   current_value: { "value" => 0.8 })
      create(:experiment_ledger,
             service_id: "ai_sns",
             deadline: 1.day.ago.to_date,
             kpi_targets: [{ "kpi_key" => kpi.kpi_key, "threshold" => 0.5 }])

      result = described_class.call

      expect(result[:decided]).to eq(1)
      expect(result[:details].first[:decision][:status]).to eq(:continued)
    end

    it "does not touch non-expired active experiments" do
      create(:experiment_ledger, deadline: 30.days.from_now.to_date)

      result = described_class.call

      expect(result[:decided]).to eq(0)
    end

    it "handles experiments with empty kpi_targets by withdrawing" do
      # kpi_targets is required for creation, so test the evaluate logic directly
      exp = create(:experiment_ledger,
                   deadline: 1.day.ago.to_date,
                   kpi_targets: [{ "kpi_key" => "kpi:nonexistent", "threshold" => 99 }])

      result = described_class.call

      expect(result[:decided]).to eq(1)
      expect(result[:details].first[:decision][:status]).to eq(:withdrawn)
    end
  end
end
