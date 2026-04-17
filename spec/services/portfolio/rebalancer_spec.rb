require "rails_helper"

RSpec.describe Portfolio::Rebalancer do
  describe ".call" do
    it "creates a PortfolioStrategyLedger with rebalance classification" do
      create(:kpi_ledger,
             kpi_key: "kpi:ai_sns:health",
             name: "ai_sns health",
             scope_level: :service,
             service_id: "ai_sns",
             status: :active,
             grade: :healthy)
      create(:kpi_ledger,
             kpi_key: "kpi:picro:health",
             name: "picro health",
             scope_level: :service,
             service_id: "picro",
             status: :active,
             grade: :critical)

      result = described_class.call(
        strategy_key: "portfolio:rebalance:test",
        period_start: Date.current - 90,
        period_end: Date.current
      )

      expect(result.strategy).to be_persisted
      expect(result.strategy.strategy_type).to eq("rebalance")
      expect(result.strategy.member_service_ids).to include("ai_sns", "picro")
      expect(result.summary[:invest_candidates].map { |h| h[:service_id] }).to include("ai_sns")
      expect(result.summary[:exit_candidates].map { |h| h[:service_id] }).to include("picro")
    end

    it "upserts on same strategy_key" do
      create(:kpi_ledger,
             kpi_key: "kpi:ai_sns:health",
             name: "ai_sns health",
             scope_level: :service,
             service_id: "ai_sns",
             status: :active,
             grade: :healthy)

      described_class.call(strategy_key: "portfolio:rebalance:test",
                           period_start: Date.current - 90, period_end: Date.current)
      described_class.call(strategy_key: "portfolio:rebalance:test",
                           period_start: Date.current - 90, period_end: Date.current)

      expect(PortfolioStrategyLedger.where(strategy_key: "portfolio:rebalance:test").count).to eq(1)
    end

    it "returns empty summary when no service-level KPIs" do
      result = described_class.call(strategy_key: "portfolio:rebalance:empty",
                                    period_start: Date.current - 90, period_end: Date.current)

      expect(result.service_scores).to eq({})
    end
  end
end
