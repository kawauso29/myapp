module AiSns
  class ObservationCollector
    OBSERVATION_WINDOW = 24.hours

    def self.call(now: Time.current)
      new(now: now).call
    end

    def initialize(now:)
      @now = now
      @window_start = now - OBSERVATION_WINDOW
      @yesterday_start = @window_start - OBSERVATION_WINDOW
    end

    def call
      posts_scope = AiPost.where(created_at: @window_start..@now)
      root_posts = posts_scope.where(reply_to_post_id: nil)
      replies_scope = posts_scope.where.not(reply_to_post_id: nil)

      yesterday_posts = AiPost.where(created_at: @yesterday_start..@window_start)
      yesterday_root  = yesterday_posts.where(reply_to_post_id: nil)

      active_poster_ids = posts_scope.select(:ai_user_id).distinct.pluck(:ai_user_id)
      total_ai_count    = AiUser.count
      silent_ai_count   = [ total_ai_count - active_poster_ids.size, 0 ].max

      provider = ENV.fetch("AI_PROVIDER", "gemini")
      llm_calls_today = LlmBudgetTracker.count(provider)

      {
        generated_at: @now.iso8601,
        window_hours: (OBSERVATION_WINDOW / 1.hour).to_i,
        totals: {
          ai_users:           total_ai_count,
          active_ai_users:    AiUser.active.count,
          active_posters_24h: active_poster_ids.size,
          silent_ai_pct:      total_ai_count > 0 ? (silent_ai_count.to_f / total_ai_count * 100).round(1) : 0.0,
          posts_24h:          root_posts.count,
          replies_24h:        replies_scope.count,
          dm_threads_24h:     AiDmThread.where(updated_at: @window_start..@now).count
        },
        engagement: {
          avg_likes_per_post_24h:    average_likes(root_posts),
          reply_rate_24h:            reply_rate(root_posts, replies_scope),
          user_likes_24h:            UserAiLike.where(created_at: @window_start..@now).count,
          new_favorites_24h:         UserFavoriteAi.where(created_at: @window_start..@now).count
        },
        trend_vs_yesterday: {
          posts_delta:       root_posts.count - yesterday_root.count,
          posts_yesterday:   yesterday_root.count
        },
        operations: {
          pending_reports:   PostReport.status_pending.count,
          failed_jobs:       safe_count(SolidQueue::FailedExecution),
          recurring_tasks:   safe_count(SolidQueue::RecurringTask),
          llm_calls_today:   llm_calls_today,
          llm_daily_limit:   (ENV["LLM_DAILY_CALL_LIMIT"] || 500).to_i
        }
      }
    end

    private

    def average_likes(scope)
      return 0.0 if scope.empty?

      (scope.sum(:likes_count).to_f / scope.count).round(2)
    end

    def reply_rate(root_posts_scope, replies_scope)
      roots = root_posts_scope.count
      return 0.0 if roots.zero?

      (replies_scope.count.to_f / roots).round(2)
    end

    def safe_count(model_class)
      model_class.count
    rescue => e
      Rails.logger.warn("[AiSns::ObservationCollector] count failed for #{model_class}: #{e.class} #{e.message}")
      0
    end
  end
end
