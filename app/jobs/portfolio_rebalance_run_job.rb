class PortfolioRebalanceRunJob < ApplicationJob
  include Ledgers::JobIdempotency
  queue_as :default

  # Phase 41b / §4.2: 四半期ごとに PortfolioStrategyLedger の rebalance を自動実行する。
  def perform
    slot = Ledgers::TimeAxis.slot_token(:quarterly)
    self.class.with_job_idempotency("portfolio_rebalance:#{slot}") do
      Portfolio::Rebalancer.call(
        period_start: Date.current - 90,
        period_end: Date.current,
        idempotency_key: "portfolio_rebalance:#{slot}"
      )
    end
  end
end
