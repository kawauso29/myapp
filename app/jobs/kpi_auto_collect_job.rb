class KpiAutoCollectJob < ApplicationJob
  queue_as :default

  # Phase A: Admin::KpiService.weekly_metrics を KpiLedger.current_value に自動投入する。
  # 日次で走り、R4 / ImprovementDetector / Reinforcements::Planner の入力データを供給する。
  def perform
    Reinforcements::KpiAutoCollector.call
  end
end
