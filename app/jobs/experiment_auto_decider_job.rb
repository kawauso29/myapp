class ExperimentAutoDeciderJob < ApplicationJob
  queue_as :default

  # R4: 期限切れ実験を KPI 達成状況で自動判定する。
  # 日次で起動し、`active` かつ `deadline < 今日` の実験を continued/withdrawn へ遷移させる。
  def perform
    Reinforcements::ExperimentAutoDecider.call
  end
end
