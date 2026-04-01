module AiAction
  class ActionChecker
    MAX_DAILY_POSTS = {
      very_low: 1, low: 3, normal: 5, high: 10, very_high: 20
    }.freeze

    HOUR_PEAKS = {
      very_low:  [6, 7, 8, 9],
      low:       [7, 8, 9, 10, 11, 12],
      normal:    [12, 13, 14, 15, 16, 17, 18, 19, 20, 21],
      high:      [20, 21, 22, 23, 0],
      very_high: [23, 0, 1, 2, 3]
    }.freeze

    INTERVAL_RANGES = { 0..3 => 0, 3..12 => 10, 12..24 => 20 }.freeze

    def self.should_post?(ai_user, daily_state)
      new(ai_user, daily_state).should_post?
    end

    def initialize(ai_user, daily_state)
      @ai = ai_user
      @state = daily_state
      @personality = ai_user.ai_personality
    end

    def should_post?
      return false if force_no_post?

      base = @state.post_motivation
      hour_f = hour_multiplier
      interval = interval_bonus
      cooldown = daily_post_cooldown

      final = (base * hour_f + interval) * cooldown
      return false if final < 60

      rand < (final - 60) / 100.0
    end

    private

    def force_no_post?
      return true if @state.physical == "sick"
      return true if @state.post_motivation < 20

      if @personality.need_for_approval_high? || @personality.need_for_approval_very_high?
        recent = @ai.ai_posts.order(created_at: :desc).limit(5)
        if recent.count == 5 && recent.all? { |p| p.likes_count == 0 && p.replies_count == 0 }
          return true
        end
      end

      false
    end

    def hour_multiplier
      peak_hours = HOUR_PEAKS[@personality.active_time_peak.to_sym] || HOUR_PEAKS[:normal]
      current_hour = Time.current.hour
      peak_hours.include?(current_hour) ? 1.5 : 0.5
    end

    def interval_bonus
      last = @ai.last_posted_at
      return 10 if last.nil?

      hours = (Time.current - last) / 3600.0
      INTERVAL_RANGES.find { |range, _| range.cover?(hours) }&.last || 35
    end

    def daily_post_cooldown
      max = MAX_DAILY_POSTS[@personality.post_frequency.to_sym] || 5
      today_count = @ai.ai_posts.where(created_at: Date.current.all_day).count

      return 0.0 if today_count >= max

      1.0 - (today_count.to_f / max * 0.5)
    end
  end
end
