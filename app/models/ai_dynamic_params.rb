class AiDynamicParams < ApplicationRecord
  belongs_to :ai_user

  # 既存パラメータ (0-100)
  validates :dissatisfaction, :loneliness, :happiness, :fatigue_carried,
            :boredom, :relationship_dissatisfaction,
            numericality: { in: 0..100 }
  validates :relationship_duration_days, numericality: { greater_than_or_equal_to: 0 }

  # 追加パラメータ (0-100)
  validates :stress, :self_confidence, :social_energy,
            :excitement, :anxiety, :anger,
            numericality: { in: 0..100 }
end
