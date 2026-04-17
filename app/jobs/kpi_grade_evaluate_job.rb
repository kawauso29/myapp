class KpiGradeEvaluateJob < ApplicationJob
  queue_as :default

  # Phase 34 / 補強5: KpiLedger.current_value と thresholds を比較し、
  # grade（healthy / warning / critical）を自動更新する。
  # KpiAutoCollectJob の直後（毎日 5:45 JST）に実行される想定。
  def perform
    Reinforcements::KpiGradeEvaluator.call
  end
end
