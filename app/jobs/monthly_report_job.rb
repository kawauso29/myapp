# 月次レポート生成ジョブ
#
# 1ヶ月の取引実績を集計し、AnalysisReport（monthly）を生成する。
# 週次レポートよりも長期的な傾向を分析する。

class MonthlyReportJob < ApplicationJob
  queue_as :analysis

  def perform
    period_start = 1.month.ago.beginning_of_day
    period_end   = Time.current.end_of_day

    Rails.logger.info "[MonthlyReportJob] 月次レポート生成開始: #{period_start} 〜 #{period_end}"

    summary = build_summary(period_start, period_end)

    report = AnalysisReport.create!(
      period_start:           period_start,
      period_end:             period_end,
      report_type:            "monthly",
      loss_patterns:          summary[:loss_patterns],
      good_skip_patterns:     summary[:skip_patterns],
      agent_accuracy:         summary[:agent_accuracy],
      improvement_suggestions: summary[:suggestions],
      status:                 "draft"
    )

    Rails.logger.info "[MonthlyReportJob] 月次レポート生成完了: ID=#{report.id}"
  rescue => e
    Rails.logger.error "[MonthlyReportJob] エラー: #{e.message}"
    raise
  end

  private

  def build_summary(start_time, end_time)
    results = TradeResult
      .joins(trade_decision: :market_snapshot)
      .where(market_snapshots: { captured_at: start_time..end_time })

    wins   = results.wins.count
    losses = results.losses.count
    total  = wins + losses
    win_rate = total.positive? ? (wins.to_f / total * 100).round(1) : 0.0

    decisions = TradeDecision
      .joins(:market_snapshot)
      .where(market_snapshots: { captured_at: start_time..end_time })

    {
      loss_patterns:  {
        total_trades:  total,
        wins:          wins,
        losses:        losses,
        win_rate:      "#{win_rate}%",
        total_pnl_usd: results.sum(:profit_loss).to_f.round(2),
        avg_win_pips:  results.wins.average(:pips)&.round(2),
        avg_loss_pips: results.losses.average(:pips)&.round(2)
      },
      skip_patterns: {
        total_skips:  decisions.skipped.count,
        total_executes: decisions.executed.count,
        skip_rate:    total.positive? ? "#{(decisions.skipped.count.to_f / decisions.count * 100).round(1)}%" : "N/A"
      },
      agent_accuracy: build_agent_accuracy(start_time, end_time),
      suggestions:    "月次レポートは人間によるレビューを推奨します。詳細は各週次レポートを参照してください。"
    }
  end

  def build_agent_accuracy(start_time, end_time)
    AgentJudgment::AGENT_TYPES.each_with_object({}) do |type, acc|
      count = AgentJudgment
        .joins(:market_snapshot)
        .where(agent_type: type)
        .where(market_snapshots: { captured_at: start_time..end_time })
        .count
      veto_count = AgentJudgment
        .joins(:market_snapshot)
        .where(agent_type: type, veto: true)
        .where(market_snapshots: { captured_at: start_time..end_time })
        .count

      acc[type] = { total: count, veto_count: veto_count }
    end
  end
end
