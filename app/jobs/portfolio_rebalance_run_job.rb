class PortfolioRebalanceRunJob < ApplicationJob
  include Ledgers::JobIdempotency
  queue_as :default

  # Phase 41b / §4.2: 四半期ごとに PortfolioStrategyLedger の rebalance を自動実行する。
  def perform
    quarter_number = ((Date.current.month - 1) / 3) + 1
    self.class.with_job_idempotency("portfolio_rebalance:#{Date.current.year}:q#{quarter_number}") do
      Portfolio::Rebalancer.call(
        period_start: Date.current - 90,
        period_end: Date.current,
        idempotency_key: "portfolio_rebalance:#{Date.current.year}:q#{quarter_number}"
      )
    end
  end
end
