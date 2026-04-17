class EffectivenessRecalcJob < ApplicationJob
  queue_as :default

  # Phase D: 完了した improvement チケットの effectiveness_score を再計算する。
  # 日次で走り、補強10 EffectivenessEvaluator の読み取りデータを供給する。
  def perform
    Reinforcements::EffectivenessRecalculator.call
  end
end
