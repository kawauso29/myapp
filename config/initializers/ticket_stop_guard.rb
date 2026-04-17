# Phase 33 / 補強7 / §18: production / development では TicketLedger 作成時に
# active StopLedger があれば起票をブロックする。
# Phase 36 / Phase 37: 同時に LaneCapacityGuard / PrGuardrail の警告ログも有効化する（警告のみ、ブロックしない）。
#
# enforce モード（`enforce_lane_capacity` / `enforce_pr_guardrail`）は警告ログで十分な
# 件数集まってから切り替える方針のため、デフォルト OFF のまま保持する。
# 切り替えは ENV 経由（`ENFORCE_LANE_CAPACITY=1` / `ENFORCE_PR_GUARDRAIL=1`）で段階的に有効化する。
#
# test 環境はデフォルト OFF（既存テストの互換のため）。
# 個別テストで有効化したい場合は around block で上書きする。
Rails.application.config.after_initialize do
  unless Rails.env.test?
    TicketLedger.enforce_stop_guard = true
    TicketLedger.warn_lane_capacity = true
    TicketLedger.warn_pr_guardrail = true
    TicketLedger.enforce_lane_capacity = true if ENV["ENFORCE_LANE_CAPACITY"] == "1"
    TicketLedger.enforce_pr_guardrail = true if ENV["ENFORCE_PR_GUARDRAIL"] == "1"
  end
end
