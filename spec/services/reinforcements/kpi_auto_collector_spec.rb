require "rails_helper"

RSpec.describe Reinforcements::KpiAutoCollector do
  describe ".call" do
    let(:metrics) do
      {
        collected_at: "2026-04-17T00:00:00Z",
        users: { total: 100, paid: 20, wau: 40, retention_30d_pct: 55.5 },
        posts: { total: 1000, this_week: 50, conversation_rate_pct: 12.0 },
        engagement: { user_likes_this_week: 30 }
      }
    end

    before do
      allow(Admin::KpiService).to receive(:weekly_metrics).and_return(metrics)
    end

    it "writes current_value for each mapped KPI that exists in KpiLedger" do
      wau = KpiLedger.create!(kpi_key: "kpi:ai_sns_wau", scope_level: :service, service_id: "ai_sns", name: "wau", status: :active)
      retention = KpiLedger.create!(kpi_key: "kpi:ai_sns_retention_7d", scope_level: :service, service_id: "ai_sns", name: "ret", status: :active)
      paid = KpiLedger.create!(kpi_key: "kpi:ai_sns_paid_conversion", scope_level: :service, service_id: "ai_sns", name: "paid", status: :active)
      health = KpiLedger.create!(kpi_key: "kpi:service_health", scope_level: :service, service_id: "ai_sns", name: "health", status: :active)

      result = described_class.call

      expect(result[:updated]).to eq(4)
      expect(wau.reload.current_value).to include("value" => 40, "source" => "kpi_auto_collector", "unit" => "users")
      expect(retention.reload.current_value).to include("value" => 55.5, "unit" => "percent")
      expect(paid.reload.current_value).to include("value" => 20.0, "unit" => "percent") # 20/100*100
      expect(health.reload.current_value["value"]).to eq(1.0)
    end

    it "skips KPIs with no source metric value" do
      allow(Admin::KpiService).to receive(:weekly_metrics).and_return({
        collected_at: "2026-04-17T00:00:00Z",
        users: { total: 0, paid: 0, wau: nil, retention_30d_pct: nil },
        posts: { this_week: 0 },
        engagement: { user_likes_this_week: 0 }
      })

      KpiLedger.create!(kpi_key: "kpi:ai_sns_retention_7d", scope_level: :service, service_id: "ai_sns", name: "ret", status: :active)
      KpiLedger.create!(kpi_key: "kpi:ai_sns_paid_conversion", scope_level: :service, service_id: "ai_sns", name: "paid", status: :active)

      result = described_class.call
      expect(result[:skipped]).to be >= 2
    end

    it "returns error metric is propagated as error" do
      allow(Admin::KpiService).to receive(:weekly_metrics).and_return({ error: "DB down", collected_at: "x" })
      result = described_class.call
      expect(result[:error]).to eq("DB down")
    end
  end
end
