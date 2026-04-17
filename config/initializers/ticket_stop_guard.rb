# Phase 33 / 補強7 / §18: production / development では TicketLedger 作成時に
# active StopLedger があれば起票をブロックする。
# Phase 36 / Phase 37: 同時に LaneCapacityGuard / PrGuardrail の警告ログも有効化する（警告のみ、ブロックしない）。
#
# test 環境はデフォルト OFF（既存テストの互換のため）。
# 個別テストで有効化したい場合は around block で上書きする。
Rails.application.config.after_initialize do
  unless Rails.env.test?
    TicketLedger.enforce_stop_guard = true
    TicketLedger.warn_lane_capacity = true
    TicketLedger.warn_pr_guardrail = true
  end
end
