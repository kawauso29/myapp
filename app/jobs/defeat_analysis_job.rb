# 敗因分析バッチジョブ（週次）
#
# 1週間の取引結果を分析し、AnalysisReport を生成する。
# 生成されたレポートは status: "draft" として保存される。
# 人間のレビュー後に "human_reviewed" → "applied" に変更することで本番反映する。
#
# 「自己改善は必ず人間が承認する」設計哲学に従い、
# このジョブは提案の生成までを自動で行い、本番反映はしない。

class DefeatAnalysisJob < ApplicationJob
  queue_as :analysis

  def perform
    period_start = 1.week.ago.beginning_of_day
    period_end   = Time.current.end_of_day

    Rails.logger.info "[DefeatAnalysisJob] 週次敗因分析開始: #{period_start} 〜 #{period_end}"

    results_in_period = fetch_results(period_start, period_end)

    if results_in_period.empty?
      Rails.logger.info "[DefeatAnalysisJob] 分析対象の取引結果なし"
      return
    end

    loss_patterns      = analyze_loss_patterns(results_in_period)
    good_skip_patterns = analyze_good_skip_patterns(period_start, period_end)
    agent_accuracy     = calculate_agent_accuracy(period_start, period_end)
    suggestions        = generate_improvement_suggestions(loss_patterns, good_skip_patterns, agent_accuracy)

    report = AnalysisReport.create!(
      period_start:           period_start,
      period_end:             period_end,
      report_type:            "weekly",
      loss_patterns:          loss_patterns,
      good_skip_patterns:     good_skip_patterns,
      agent_accuracy:         agent_accuracy,
      improvement_suggestions: suggestions,
      status:                 "draft"
    )

    Rails.logger.info "[DefeatAnalysisJob] レポート生成完了: ID=#{report.id} (人間レビュー待ち)"
  rescue => e
    Rails.logger.error "[DefeatAnalysisJob] エラー: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    raise
  end

  private

  def fetch_results(start_time, end_time)
    TradeResult
      .joins(trade_decision: :market_snapshot)
      .where(market_snapshots: { captured_at: start_time..end_time })
      .includes(trade_decision: [:market_snapshot, { market_snapshot: :agent_judgments }])
  end

  def analyze_loss_patterns(results)
    losses = results.select(&:loss?)
    return {} if losses.empty?

    {
      total_losses:    losses.size,
      avg_loss_pips:   losses.sum(&:pips).to_f / losses.size,
      total_loss_usd:  losses.sum(&:profit_loss).to_f,
      market_states:   losses.group_by { |r| r.trade_decision.market_snapshot.state }.transform_values(&:size),
      directions:      losses.group_by { |r| r.trade_decision.direction }.transform_values(&:size)
    }
  end

  def analyze_good_skip_patterns(start_time, end_time)
    # skip_correct（見送って正解）の傾向を分析
    skip_corrects = TradeResult
      .joins(trade_decision: :market_snapshot)
      .where(market_snapshots: { captured_at: start_time..end_time })
      .where(outcome: "skip_correct")

    {
      total:        skip_corrects.count,
      skip_reasons: TradeDecision
        .joins(:market_snapshot)
        .where(market_snapshots: { captured_at: start_time..end_time })
        .where(decision: "skip")
        .group(:skip_reason)
        .count
    }
  end

  def calculate_agent_accuracy(start_time, end_time)
    AgentJudgment::AGENT_TYPES.each_with_object({}) do |agent_type, acc|
      judgments = AgentJudgment
        .joins(market_snapshot: { trade_decisions: :trade_result })
        .where(agent_type: agent_type)
        .where(market_snapshots: { captured_at: start_time..end_time })

      total = judgments.count
      next if total.zero?

      correct = judgments
        .joins("INNER JOIN trade_decisions ON trade_decisions.market_snapshot_id = market_snapshots.id")
        .joins("INNER JOIN trade_results ON trade_results.trade_decision_id = trade_decisions.id")
        .where("(agent_judgments.judgment = 'buy' AND trade_results.outcome = 'win' AND trade_decisions.direction = 'buy') OR " \
               "(agent_judgments.judgment = 'sell' AND trade_results.outcome = 'win' AND trade_decisions.direction = 'sell') OR " \
               "(agent_judgments.judgment = 'skip' AND trade_results.outcome IN ('skip_correct'))")
        .count

      acc[agent_type] = { total: total, correct: correct, accuracy: (correct.to_f / total * 100).round(1) }
    end
  end

  def generate_improvement_suggestions(loss_patterns, good_skip_patterns, agent_accuracy)
    client = Anthropic::Client.new

    system_prompt = <<~PROMPT
      あなたはNAS100（ナスダック100）自動売買システムの改善を担うAIアナリストです。
      提供された損失パターン・見送りパターン・エージェント別精度データを分析し、
      システム改善の提案を日本語で生成してください。

      重要な制約:
      - 提案は具体的かつ実装可能なものにすること
      - 「人間によるレビュー・承認後に実装」という前提で提案すること
      - 過度なリスクを増やす方向の提案はしないこと
    PROMPT

    user_message = <<~MSG
      週次分析データ:

      損失パターン:
      #{JSON.pretty_generate(loss_patterns)}

      見送り正解パターン:
      #{JSON.pretty_generate(good_skip_patterns)}

      エージェント別精度:
      #{JSON.pretty_generate(agent_accuracy)}

      これらのデータから、システム改善の提案を3〜5点にまとめてください。
    MSG

    response = client.messages(
      parameters: {
        model:      "claude-opus-4-6",
        max_tokens: 2048,
        system:     system_prompt,
        messages:   [{ role: "user", content: user_message }]
      }
    )

    response.dig("content", 0, "text").to_s
  rescue => e
    Rails.logger.error "[DefeatAnalysisJob] Claude API error: #{e.message}"
    "AIによる改善提案生成に失敗しました。手動でレビューしてください。"
  end
end
