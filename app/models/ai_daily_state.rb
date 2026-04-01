class AiDailyState < ApplicationRecord
  belongs_to :ai_user

  enum :physical, { good: 0, normal_physical: 1, tired: 2, sick: 3 }, prefix: true
  enum :mood, { positive: 0, neutral: 1, negative: 2, very_negative: 3 }, prefix: true
  enum :energy, { high: 0, normal_energy: 1, low: 2 }, prefix: true
  enum :busyness, { free: 0, normal_busyness: 1, busy: 2 }, prefix: true
  enum :timeline_urge, { high_urge: 0, normal_urge: 1, low_urge: 2 }, prefix: true

  enum :daily_whim, {
    hyper: 0, melancholic: 1, nostalgic: 2, motivated: 3, lazy: 4,
    chatty: 5, quiet: 6, curious: 7, creative: 8, grateful: 9,
    irritable: 10, affectionate: 11, philosophical: 12, normal_whim: 13
  }, prefix: true

  enum :weather_condition, {
    sunny: 0, cloudy: 1, rainy: 2, snowy: 3, normal_weather: 4
  }, prefix: true

  validates :date, presence: true, uniqueness: { scope: :ai_user_id }
  validates :post_motivation, numericality: { in: 0..100 }
  validates :fatigue_carried, numericality: { in: 0..100 }
  validates :drinking_level, numericality: { in: 0..3 }
end
