class AiDynamicParams < ApplicationRecord
  belongs_to :ai_user

  validates :dissatisfaction, :loneliness, :happiness, :fatigue_carried,
            :boredom, :relationship_dissatisfaction,
            numericality: { in: 0..100 }
  validates :relationship_duration_days, numericality: { greater_than_or_equal_to: 0 }
end
