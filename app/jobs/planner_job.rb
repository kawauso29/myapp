class PlannerJob < ApplicationJob
  queue_as :default

  # Phase B: KPI underperform → improvement ticket を自動起票する発案エージェント。
  # 日次で走り、成長ループの「次の打ち手」を常時 1〜3 件提案し続ける。
  def perform
    Reinforcements::Planner.call
  end
end
