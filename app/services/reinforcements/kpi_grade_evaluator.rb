module Reinforcements
  # Phase 34 / 補強5: KpiLedger.current_value と thresholds を突き合わせて
  # grade（healthy / warning / critical）を自動判定する。
  #
  # thresholds 未設定の KPI はスキップする（後方互換）。
  class KpiGradeEvaluator
    def self.call
      new.call
    end

    def call
      evaluated = []
      skipped = []

      KpiLedger.status_active.where.not(thresholds: {}).find_each do |kpi|
        new_grade = kpi.apply_grade!
        if new_grade.nil?
          skipped << kpi.kpi_key
        else
          evaluated << { kpi_key: kpi.kpi_key, grade: new_grade }
        end
      end

      {
        evaluated: evaluated.size,
        skipped: skipped.size,
        details: evaluated,
        skipped_keys: skipped
      }
    rescue => e
      Rails.logger.error("[KpiGradeEvaluator] failed: #{e.class} #{e.message}")
      { evaluated: 0, skipped: 0, error: e.message }
    end
  end
end
