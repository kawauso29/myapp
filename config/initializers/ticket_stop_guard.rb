# Phase 33 / 補強7 / §18: production / development では TicketLedger 作成時に
# active StopLedger があれば起票をブロックする。
# Phase 36 / Phase 37: 同時に LaneCapacityGuard / PrGuardrail の警告ログも有効化する（警告のみ、ブロックしない）。
#
# enforce モード（`enforce_lane_capacity` / `enforce_pr_guardrail` / `enforce_template`）は
# 警告ログで十分な件数集まってから切り替える方針のため、デフォルト OFF のまま保持する。
# 切り替えは ENV 経由で段階的に有効化する:
#   - `ENFORCE_LANE_CAPACITY=1`: WIP 上限超過で起票をブロック
#   - `ENFORCE_PR_GUARDRAIL=1`: ADR/Runbook 不足で起票をブロック
#   - `ENFORCE_TEMPLATE=1`: template_id 未設定で起票をブロック
#   - `ENFORCE_AUDIT_REASON=1`: 非承認監査判断に reason_detail を必須化
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
    TicketLedger.enforce_template = true if ENV["ENFORCE_TEMPLATE"] == "1"
    AuditDecisionLedger.enforce_audit_reason = true if ENV["ENFORCE_AUDIT_REASON"] == "1"
  end
end
