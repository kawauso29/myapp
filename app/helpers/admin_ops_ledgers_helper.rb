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

  MEETING_TYPE_SUMMARY = {
    "daily"            => "日次KPIスナップショット取得・異常検知（会議なし／自動実行）",
    "weekly"           => "週次チケット起票会議（KPI異常 → TicketLedger 作成）",
    "monthly"          => "月次運営レビュー（週次チケット + KPI月次集計）",
    "quarterly_review" => "四半期レビュー（月次の進捗総括 + 戦略判断）",
    "annual_plan"      => "年次計画（四半期を踏まえた年間方針決定）"
  }.freeze

  MEETING_ROLE_DESCRIPTION = {
    "daily"            => "システムが自動で各KPIの現在値を取得し、critical になったKPIを「異常」として記録します。" \
                          "異常が積み重なると次の weekly 会議でチケット化されます。",
    "weekly"           => "DailyRunnerが検知した異常・事業要求を元に TicketLedger を起票します。" \
                          "KPIに紐付けできないチケット候補は hold_items に保留されます。",
    "monthly"          => "週次チケットの進捗レビューと、月次集計KPIに基づく方針決定を行います。",
    "quarterly_review" => "月次結果を総括し、四半期単位での戦略修正・投資優先度を決定します。",
    "annual_plan"      => "年間ビジョンと重点KPIを決定します。四半期レビューの積み上げが入力となります。"
  }.freeze

  # KPI の current_value ハッシュから表示用の値を抽出する。
  # {"value" => 1.5, "unit" => "users", ...} → "1.5 users"
  # {} または nil → nil（呼び出し元で「未収集」等と表示する）
  def format_kpi_current_value(val)
    return nil if val.blank?

    hash = val.is_a?(Hash) ? val : {}
    raw = hash["value"] || hash[:value]
    return nil if raw.nil?

    unit = hash["unit"] || hash[:unit]
    numeric = raw.is_a?(Float) ? raw.round(2) : raw
    unit.present? ? "#{numeric} #{unit}" : numeric.to_s
  end

  # KPI の current_value から recorded_at を返す。
  def kpi_recorded_at(val)
    return nil unless val.is_a?(Hash)

    recorded = val["recorded_at"] || val[:recorded_at]
    return nil unless recorded

    Time.zone.parse(recorded.to_s).in_time_zone("Tokyo").strftime("%m/%d %H:%M")
  rescue ArgumentError
    nil
  end

  # Meeting タイプに対応する日本語サマリを返す。
  def meeting_type_summary(meeting)
    MEETING_TYPE_SUMMARY[meeting.meeting_type.to_s] || meeting.meeting_type.to_s
  end

  # Meeting タイプに対応する役割説明を返す。
  def meeting_role_description(meeting)
    MEETING_ROLE_DESCRIPTION[meeting.meeting_type.to_s]
  end
end
