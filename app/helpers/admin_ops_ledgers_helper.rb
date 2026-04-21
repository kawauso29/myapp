module AdminOpsLedgersHelper
  LEDGER_HOLD_REASON_LABELS = {
    "anomaly"                => "⚠️ 異常検知（KPI critical）",
    "missing_linked_kpis"    => "📋 KPI未紐付け（チケット保留）",
    "missing_kpi_definition" => "📋 KPI定義なし（チケット保留）",
    "entry_guard_blocked"    => "🛑 稼働停止中（チケット保留）",
    "escalation"             => "🔺 上位レビュー待ち"
  }.freeze

  LEDGER_GRADE_COLOR = {
    "critical" => "#fc8181",
    "warning"  => "#f6ad55",
    "healthy"  => "#68d391"
  }.freeze
end
