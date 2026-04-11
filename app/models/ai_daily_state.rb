class AiDailyState < ApplicationRecord
  belongs_to :ai_user

  # ── 既存enum ───────────────────────────────
  enum :physical,         { good: 0, normal_physical: 1, tired: 2, sick: 3 },          prefix: true
  enum :mood,             { positive: 0, neutral: 1, negative: 2, very_negative: 3 },  prefix: true
  enum :energy,           { high: 0, normal_energy: 1, low: 2 },                        prefix: true
  enum :busyness,         { free: 0, normal_busyness: 1, busy: 2 },                     prefix: true
  enum :timeline_urge,    { high_urge: 0, normal_urge: 1, low_urge: 2 },               prefix: true

  enum :daily_whim, {
    hyper: 0, melancholic: 1, nostalgic: 2, motivated: 3, lazy: 4,
    chatty: 5, quiet: 6, curious: 7, creative: 8, grateful: 9,
    irritable: 10, affectionate: 11, philosophical: 12, normal_whim: 13
  }, prefix: true

  enum :weather_condition, {
    sunny: 0, cloudy: 1, rainy: 2, snowy: 3, normal_weather: 4
  }, prefix: true

  # ── 追加enum ───────────────────────────────
  # 集中力
  enum :concentration, {
    high_concentration: 0, normal_concentration: 1, low_concentration: 2
  }, prefix: true

  # 食欲
  enum :appetite, {
    big_appetite: 0, normal_appetite: 1, small_appetite: 2, no_appetite: 3
  }, prefix: true

  # 朝の目覚め
  enum :morning_mood, {
    great_morning: 0, good_morning: 1, ok_morning: 2, bad_morning: 3, terrible_morning: 4
  }, prefix: true

  # ── バリデーション ──────────────────────────
  validates :date,            presence: true, uniqueness: { scope: :ai_user_id }
  validates :post_motivation, numericality: { in: 0..100 }
  validates :fatigue_carried, numericality: { in: 0..100 }
  validates :drinking_level,  numericality: { in: 0..3 }
  validates :stress_level,    numericality: { in: 0..100 }
  validates :social_battery,  numericality: { in: 0..100 }

  # hourly_states: [{hour: 10, mood_delta: +5, activity: "ダンスレッスン", location: "スタジオ", note: "..."}, ...]
  # 時間ごとの状態スナップショット（HourlyStateUpdateJobが書き込む）
end
