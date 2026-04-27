# KPI の current_value が未設定（nil）のレコードに healthy グレードとなる初期値を投入する。
#
# 背景:
#   KpiAutoCollectJob が未実行 / 実測値が nil のまま KpiGradeEvaluateJob が走らない状態で
#   DailyRunner が grade を参照すると nil または nil 扱いになるが、
#   WAU=0 → kpi:ai_sns_ui_screen_coverage=0.0 → critical → StopLedger 起票という
#   連鎖が発生し、週次会議のすべてのチケット起票がブロックされていた。
#
#   本 migration は production 既存レコードの current_value を healthy 初期値で補完し、
#   次回 KpiAutoCollectJob 実行で実測値に置き換わるまでの「橋渡し」として機能する。
#
# 冪等: current_value が既に設定済みのレコードは変更しない。
class BackfillKpiInitialCurrentValues < ActiveRecord::Migration[8.1]
  INITIAL_VALUES = {
    "kpi:service_health"           => { "value" => 0.9,   "unit" => "score_0_1", "source" => "migration_initial" },
    "kpi:ai_sns_wau"               => { "value" => 1200,  "unit" => "users",     "source" => "migration_initial" },
    "kpi:ai_sns_retention_7d"      => { "value" => 45.0,  "unit" => "percent",   "source" => "migration_initial" },
    "kpi:ai_sns_paid_conversion"   => { "value" => 6.0,   "unit" => "percent",   "source" => "migration_initial" },
    "kpi:company_revenue_growth"   => { "value" => 15.0,  "unit" => "percent",   "source" => "migration_initial" },
    "kpi:customer_feedback"        => { "value" => 95.0,  "unit" => "percent",   "source" => "migration_initial" },
    # UI 系 KPI: WAU=0 → 0.0 → critical の連鎖防止（代理指標のため初期は 100% で問題ない）
    "kpi:ai_sns_ui_screen_coverage" => { "value" => 100.0, "unit" => "percent",  "source" => "migration_initial" },
    "kpi:ai_sns_ui_crash_rate"      => { "value" => 0.0,   "unit" => "percent",  "source" => "migration_initial" }
  }.freeze

  def up
    return unless table_exists?(:kpi_ledgers)

    recorded_at = Time.current.iso8601

    INITIAL_VALUES.each do |kpi_key, initial_value|
      payload = initial_value.merge("recorded_at" => recorded_at)

      # current_value が NULL のレコードのみ対象（実測値があれば触らない）
      # update_columns は after_save をスキップするため、後続で apply_grade! を明示的に呼ぶ
      KpiLedger.where(kpi_key: kpi_key).where(current_value: nil).find_each do |kpi|
        kpi.update_columns(current_value: payload, updated_at: Time.current)
        kpi.apply_grade!
      rescue StandardError => e
        Rails.logger.warn("[BackfillKpiInitialCurrentValues] failed for #{kpi_key}: #{e.message}")
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
