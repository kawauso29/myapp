# MT4ブリッジ
#
# MT4 EA（Expert Advisor）からのシグナルリクエストに対して
# 最新の売買シグナルを返す。
#
# MT4 EA 側からは以下のような HTTP GET リクエストが来る:
#   GET http://localhost:3000/api/v1/signal
#
# 返却する JSON:
#   {
#     "action": "buy" | "sell" | "hold",
#     "lot":    0.01,          # 推奨ロット数
#     "sl":     50,            # ストップロス（pips）
#     "tp":     100,           # テイクプロフィット（pips）
#     "comment": "NAS100-AI-AGENT"
#   }

class Mt4Bridge
  include HTTParty

  DEFAULT_LOT    = 0.01
  SL_PIPS        = 50
  TP_PIPS        = 100

  # 最新の ExecuteシグナルをMT4向けJSONに変換
  # @return [Hash]
  def current_signal
    latest_decision = TradeDecision
      .where(decision: "execute")
      .order(created_at: :desc)
      .first

    if latest_decision.nil? || signal_expired?(latest_decision)
      return hold_signal("シグナルなし または期限切れ")
    end

    {
      action:  latest_decision.direction,
      lot:     DEFAULT_LOT,
      sl:      SL_PIPS,
      tp:      TP_PIPS,
      comment: "NAS100-AI #{latest_decision.id}",
      score:   latest_decision.final_score&.round(1)
    }
  end

  private

  # シグナルの有効期限は15分
  SIGNAL_TTL_MINUTES = 15

  def signal_expired?(decision)
    decision.created_at < SIGNAL_TTL_MINUTES.minutes.ago
  end

  def hold_signal(reason)
    { action: "hold", lot: 0, sl: 0, tp: 0, comment: reason }
  end
end
