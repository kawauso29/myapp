# Layer 3: リスク管理エージェント（最終砦）
#
# オーケストレーターが「execute」と判断した後の最終チェック。
# 以下のいずれかに該当する場合は強制的に skip に変更する:
#
#   - 最大ドローダウン超過
#   - 1日の最大損失額超過
#   - 連敗数がスランプ閾値を超えている
#   - 日次損失率が閾値を超えている

class RiskManager
  # リスク制限値（デモ口座デフォルト値。将来的にはDB/設定ファイルで管理）
  MAX_DAILY_LOSS_USD       = 200.0   # 1日の最大損失額（USD）
  MAX_DRAWDOWN_PERCENT     = 10.0    # 最大ドローダウン（口座残高比%）
  MAX_CONSECUTIVE_LOSSES   = 5       # 連敗数スランプ閾値
  ACCOUNT_BALANCE_USD      = 10_000.0 # デモ口座残高（USD）※実際はMT4から取得

  # @param trade_decision [TradeDecision]
  # @return [TradeDecision] スキップに変更された場合は新しい判断、そのままの場合は元の判断
  def validate(trade_decision)
    return trade_decision if trade_decision.decision == "skip"

    block_reason = check_risk_limits
    return trade_decision if block_reason.nil?

    Rails.logger.warn "[RiskManager] 執行ブロック: #{block_reason}"
    trade_decision.update!(decision: "skip", skip_reason: "リスク管理ブロック: #{block_reason}")
    trade_decision
  end

  private

  def check_risk_limits
    return "連敗スランプ検知 (#{consecutive_losses}連敗)" if consecutive_losses >= MAX_CONSECUTIVE_LOSSES
    return "1日の最大損失超過 ($#{daily_loss.abs.round(2)})" if daily_loss_exceeded?
    return "最大ドローダウン超過 (#{current_drawdown_percent.round(2)}%)" if drawdown_exceeded?

    nil
  end

  def consecutive_losses
    TradeResult
      .joins(trade_decision: :market_snapshot)
      .where(outcome: "loss")
      .order("market_snapshots.captured_at DESC")
      .limit(MAX_CONSECUTIVE_LOSSES)
      .count
      .tap do |count|
        # 直近N件が全てlossの場合のみカウント（途中でwinがあればリセット）
        recent = TradeResult
          .joins(trade_decision: :market_snapshot)
          .order("market_snapshots.captured_at DESC")
          .limit(MAX_CONSECUTIVE_LOSSES)
          .pluck(:outcome)
        return recent.take_while { |o| o == "loss" }.size
      end
  end

  def daily_loss
    today_results = TradeResult
      .joins(trade_decision: :market_snapshot)
      .where("market_snapshots.captured_at >= ?", Time.current.beginning_of_day)
      .sum(:profit_loss)
    today_results.to_f
  end

  def daily_loss_exceeded?
    daily_loss < -MAX_DAILY_LOSS_USD
  end

  def current_drawdown_percent
    max_balance = TradeResult
      .joins(trade_decision: :market_snapshot)
      .where("market_snapshots.captured_at >= ?", 30.days.ago)
      .sum(:profit_loss)
      .to_f + ACCOUNT_BALANCE_USD

    return 0.0 if max_balance <= 0

    current_balance = ACCOUNT_BALANCE_USD + TradeResult.sum(:profit_loss).to_f
    ((max_balance - current_balance) / max_balance * 100).clamp(0.0, 100.0)
  end

  def drawdown_exceeded?
    current_drawdown_percent >= MAX_DRAWDOWN_PERCENT
  end
end
