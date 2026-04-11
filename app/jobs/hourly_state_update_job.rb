class HourlyStateUpdateJob < ApplicationJob
  include JobErrorHandling

  queue_as :default

  def perform
    current_hour = Time.current.in_time_zone("Tokyo").hour
    today = Date.current

    Rails.logger.info("[HourlyStateUpdateJob] Running for hour=#{current_hour}")

    AiUser.where(is_active: true).find_each(batch_size: 100) do |ai|
      update_for(ai, today, current_hour)
    rescue => e
      Rails.logger.error("[HourlyStateUpdateJob] Failed for ai_id=#{ai.id}: #{e.class} #{e.message}")
      next
    end
  end

  private

  def update_for(ai, today, hour)
    daily_state = ai.ai_daily_states.find_by(date: today)
    return unless daily_state

    schedule = ai.ai_daily_schedules.find_by(scheduled_date: today)
    snapshot = build_snapshot(daily_state, schedule, hour)

    # hourly_states 配列に追記（同じ時間のものは上書き）
    states = daily_state.hourly_states.reject { |s| s["hour"] == hour }
    states << snapshot
    states.sort_by! { |s| s["hour"] }

    daily_state.update_columns(hourly_states: states)

    # 現在のアクティビティに応じてストレス・social_battery を微調整
    apply_activity_effects(daily_state, snapshot, hour)
  end

  def build_snapshot(daily_state, schedule, hour)
    current_item = schedule&.current_activity(hour)
    upcoming     = schedule&.upcoming_activities(hour, limit: 2) || []

    snapshot = {
      "hour"           => hour,
      "mood_delta"     => calculate_mood_delta(daily_state, schedule, hour),
      "stress_delta"   => calculate_stress_delta(current_item),
      "activity"       => current_item&.dig("activity") || infer_activity(hour),
      "location"       => current_item&.dig("location") || "自宅",
      "energy_level"   => daily_state.energy,
      "note"           => current_item&.dig("note").presence,
      "upcoming"       => upcoming.map { |u| "#{u['hour']}時: #{u['activity']}" }
    }
    snapshot
  end

  def calculate_mood_delta(daily_state, schedule, hour)
    return 0 unless schedule

    past = schedule.past_activities(hour)
    delta = past.sum { |item| item["mood_impact"].to_i }
    delta.clamp(-20, 20)
  end

  def calculate_stress_delta(current_item)
    return 0 unless current_item

    energy_cost = current_item["energy_cost"].to_i
    # エネルギーコストが高い活動はストレス増加
    if energy_cost > 20
      +5
    elsif energy_cost > 10
      +2
    elsif energy_cost < 3
      -3
    else
      0
    end
  end

  def infer_activity(hour)
    case hour
    when 0..5  then "睡眠中"
    when 6..7  then "起床・朝の準備"
    when 8..11 then "午前の活動"
    when 12..13 then "昼食"
    when 14..17 then "午後の活動"
    when 18..19 then "夕食"
    when 20..22 then "夜のリラックスタイム"
    when 23 then "就寝準備"
    else "休憩"
    end
  end

  def apply_activity_effects(daily_state, snapshot, hour)
    stress_delta  = snapshot["stress_delta"].to_i
    mood_delta    = snapshot["mood_delta"].to_i

    updates = {}

    if stress_delta != 0
      new_stress = (daily_state.stress_level + stress_delta).clamp(0, 100)
      updates[:stress_level] = new_stress
    end

    # social_battery は夕方以降に自然回復
    if hour >= 20
      new_battery = (daily_state.social_battery + 5).clamp(0, 100)
      updates[:social_battery] = new_battery
    end

    daily_state.update_columns(updates) if updates.any?
  end
end
