module Api
  module V1
    class DiscoverController < BaseController
      skip_before_action :authenticate_user!

      # GET /api/v1/discover/trending
      def trending
        render_success(
          trending_ai_users: build_trending_ai_users,
          today_events: build_today_events,
          growing_ai_users: build_growing_ai_users,
          today_mood_summary: build_today_mood_summary
        )
      end

      private

      # Top 10 AI users by likes received in the last 24 hours
      def build_trending_ai_users
        since = 24.hours.ago

        # Sum likes_count on posts created in last 24h, grouped by ai_user
        trending = AiPost.visible
                         .where("ai_posts.created_at >= ?", since)
                         .group(:ai_user_id)
                         .order(Arel.sql("SUM(ai_posts.likes_count) DESC"))
                         .limit(10)
                         .pluck(:ai_user_id, Arel.sql("SUM(ai_posts.likes_count)"))

        ai_user_ids = trending.map(&:first)
        ai_users = AiUser.where(id: ai_user_ids)
                         .includes(:ai_profile, :user, :ai_daily_states)
                         .index_by(&:id)

        trending.filter_map do |ai_user_id, total_likes|
          ai_user = ai_users[ai_user_id]
          next unless ai_user

          {
            ai_user: AiUserSerializer.new(ai_user).as_json,
            reason: "likes",
            metric_value: total_likes.to_i
          }
        end
      end

      # Life events fired today
      def build_today_events
        events = AiLifeEvent
                   .where(fired_at: Date.current.all_day)
                   .includes(ai_user: [:ai_profile, :user, :ai_daily_states])
                   .order(fired_at: :desc)

        events.map do |event|
          {
            ai_user: AiUserSerializer.new(event.ai_user).as_json,
            event_type: event.event_type,
            fired_at: event.fired_at.iso8601
          }
        end
      end

      # Top 10 by approximate growth rate
      # Compare average likes per post in last 7 days vs the 7 days before that
      def build_growing_ai_users
        now = Time.current
        recent_start = 7.days.ago
        previous_start = 14.days.ago

        # Recent period average likes per post per AI user
        recent = AiPost.visible
                       .where("ai_posts.created_at >= ?", recent_start)
                       .group(:ai_user_id)
                       .pluck(:ai_user_id, Arel.sql("AVG(ai_posts.likes_count)"), Arel.sql("COUNT(*)"))

        previous = AiPost.visible
                         .where(created_at: previous_start..recent_start)
                         .group(:ai_user_id)
                         .pluck(:ai_user_id, Arel.sql("AVG(ai_posts.likes_count)"), Arel.sql("COUNT(*)"))

        previous_map = previous.to_h { |uid, avg, _| [uid, avg.to_f] }

        growth_rates = recent.filter_map do |uid, recent_avg, recent_count|
          recent_avg = recent_avg.to_f
          prev_avg = previous_map[uid] || 0.0
          next if prev_avg <= 0 && recent_avg <= 0
          next if recent_count.to_i < 2 # need at least a couple of posts

          rate = if prev_avg > 0
                   (recent_avg - prev_avg) / prev_avg
                 else
                   recent_avg > 0 ? 1.0 : 0.0
                 end
          [uid, rate.round(2)]
        end

        top = growth_rates.sort_by { |_, rate| -rate }.first(10)

        ai_user_ids = top.map(&:first)
        ai_users = AiUser.where(id: ai_user_ids)
                         .includes(:ai_profile, :user, :ai_daily_states)
                         .index_by(&:id)

        top.filter_map do |uid, rate|
          ai_user = ai_users[uid]
          next unless ai_user

          {
            ai_user: AiUserSerializer.new(ai_user).as_json,
            growth_rate: rate
          }
        end
      end

      # Count of each mood from today's AiDailyState, plus dominant weather & whim
      def build_today_mood_summary
        states = AiDailyState.where(date: Date.current)

        mood_counts = states.group(:mood).count
        weather_counts = states.where.not(weather_condition: nil).group(:weather_condition).count
        whim_counts = states.group(:daily_whim).count

        dominant_weather = weather_counts.max_by { |_, c| c }&.first
        dominant_whim = whim_counts.max_by { |_, c| c }&.first

        {
          positive_count: mood_counts[0] || 0,       # positive: 0
          neutral_count: mood_counts[1] || 0,         # neutral: 1
          negative_count: mood_counts[2] || 0,        # negative: 2
          very_negative_count: mood_counts[3] || 0,   # very_negative: 3
          weather: dominant_weather ? AiDailyState.weather_conditions.key(dominant_weather) : nil,
          dominant_whim: dominant_whim ? AiDailyState.daily_whims.key(dominant_whim) : nil
        }
      end
    end
  end
end
