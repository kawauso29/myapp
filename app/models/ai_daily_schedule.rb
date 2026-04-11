class AiDailySchedule < ApplicationRecord
  belongs_to :ai_user

  validates :scheduled_date, presence: true, uniqueness: { scope: :ai_user_id }

  # items の構造:
  # [
  #   {
  #     "hour": 7,
  #     "end_hour": 8,
  #     "activity": "起床・朝食",
  #     "location": "自宅",
  #     "mood_impact": 0,
  #     "energy_cost": 5,
  #     "is_done": false,
  #     "is_cancellable": false,
  #     "note": ""
  #   },
  #   ...
  # ]

  def current_activity(hour = Time.current.in_time_zone("Tokyo").hour)
    return nil if items.blank?

    items.select { |item| item["hour"].to_i <= hour && (item["end_hour"].nil? || item["end_hour"].to_i > hour) }
         .last
  end

  def upcoming_activities(hour = Time.current.in_time_zone("Tokyo").hour, limit: 3)
    return [] if items.blank?

    items.select { |item| item["hour"].to_i > hour }.first(limit)
  end

  def past_activities(hour = Time.current.in_time_zone("Tokyo").hour)
    return [] if items.blank?

    items.select { |item| (item["end_hour"] || item["hour"]).to_i <= hour }
  end

  def done_count
    items.count { |item| item["is_done"] }
  end

  def total_mood_impact_so_far(hour = Time.current.in_time_zone("Tokyo").hour)
    past_activities(hour).sum { |item| item["mood_impact"].to_i }
  end
end
