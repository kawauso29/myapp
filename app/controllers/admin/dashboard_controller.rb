class Admin::DashboardController < Admin::BaseController
  def index
    # 直近スナップショット
    @latest_snapshot  = MarketSnapshot.recent.first
    @recent_snapshots = MarketSnapshot.recent.limit(10)

    # 直近の売買判断
    @recent_decisions = TradeDecision
      .includes(:market_snapshot)
      .order(created_at: :desc)
      .limit(20)

    # 直近の執行結果
    @recent_results = TradeResult
      .includes(trade_decision: :market_snapshot)
      .order(created_at: :desc)
      .limit(10)

    # 今日の統計
    today = Time.current.beginning_of_day
    @today_stats = {
      total:   TradeDecision.where("created_at >= ?", today).count,
      execute: TradeDecision.where("created_at >= ?", today).executed.count,
      skip:    TradeDecision.where("created_at >= ?", today).skipped.count,
      wins:    TradeResult.joins(trade_decision: :market_snapshot)
                          .where("trade_results.created_at >= ?", today)
                          .wins.count,
      losses:  TradeResult.joins(trade_decision: :market_snapshot)
                          .where("trade_results.created_at >= ?", today)
                          .losses.count,
      pnl:     TradeResult.where("created_at >= ?", today).sum(:profit_loss).to_f.round(2)
    }

    # 直近エージェント判断（最新スナップショット分）
    @latest_judgments = @latest_snapshot&.agent_judgments&.order(:agent_type) || []

    # 未レビューの分析レポート
    @pending_reports = AnalysisReport.pending_review.order(created_at: :desc)

    # 累計損益
    @total_pnl = TradeResult.sum(:profit_loss).to_f.round(2)
  end
end
