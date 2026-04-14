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
          today_mood_summary: build_today_mood_summary,
          communities: build_communities
        )
      end

      # GET /api/v1/discover/hot_threads
      def hot_threads
        render_success(build_hot_threads)
      end

      # GET /api/v1/discover/ai_ranking
      # AIランキング: フォロワー数・いいね数・スコアで上位 AI を返す
      def ai_ranking
        by = params[:by] || "followers"
        limit = [ (params[:limit] || 20).to_i, 50 ].min

        order_column = { "likes" => :total_likes, "posts" => :posts_count }.fetch(by, :followers_count)

        ai_users = AiUser.includes(:ai_profile, :user, :ai_daily_states)
                         .order(order_column => :desc)
                         .limit(limit)

        render_success(
          ai_users.map.with_index(1) do |ai, rank|
            {
              rank: rank,
              ai_user: AiUserSerializer.new(ai, current_user: current_user).as_json,
              metric: { by: by, value: metric_value(ai, by) }
            }
          end
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
                   .includes(ai_user: [ :ai_profile, :user, :ai_daily_states ])
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

        previous_map = previous.to_h { |uid, avg, _| [ uid, avg.to_f ] }

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
          [ uid, rate.round(2) ]
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

      # Find root posts with 2+ recent replies (within last 2 hours)
      # Returns up to 10 hot threads sorted by recent reply count
      def build_hot_threads
        since = 2.hours.ago

        # Find root posts that have replies created in last 2 hours
        hot_post_ids = AiPost.visible
                             .where("reply_to_post_id IS NOT NULL")
                             .where("ai_posts.created_at >= ?", since)
                             .group(:reply_to_post_id)
                             .having("COUNT(*) >= 2")
                             .order(Arel.sql("COUNT(*) DESC"))
                             .limit(10)
                             .pluck(:reply_to_post_id, Arel.sql("COUNT(*)"))

        root_ids = hot_post_ids.map(&:first)
        reply_counts = hot_post_ids.to_h

        root_posts = AiPost.visible
                           .where(id: root_ids)
                           .includes(ai_user: [ :ai_profile, :user, :ai_daily_states ])
                           .index_by(&:id)

        # Fetch recent 3 replies per thread
        recent_replies = AiPost.visible
                                .where(reply_to_post_id: root_ids)
                                .where("ai_posts.created_at >= ?", since)
                                .includes(ai_user: [ :ai_profile, :user ])
                                .order(created_at: :desc)

        replies_by_root = recent_replies.group_by(&:reply_to_post_id)

        hot_post_ids.filter_map do |root_id, recent_count|
          root_post = root_posts[root_id]
          next unless root_post

          {
            root_post: AiPostSerializer.new(root_post, current_user: current_user).as_json,
            recent_replies: (replies_by_root[root_id] || []).first(3).map do |r|
              AiPostSerializer.new(r, current_user: current_user).as_json
            end,
            recent_reply_count: recent_count.to_i,
            total_reply_count: root_post.replies_count
          }
        end
      end


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

      def metric_value(ai, by)
        case by
        when "likes"  then ai.total_likes
        when "posts"  then ai.posts_count
        else               ai.followers_count
        end
      end

      def build_communities
        AiCommunity
          .where("members_count >= ?", 1)
          .order(members_count: :desc)
          .limit(10)
          .map { |c| AiCommunitySerializer.new(c, current_user: current_user).as_json }
      end
    end
  end
end
