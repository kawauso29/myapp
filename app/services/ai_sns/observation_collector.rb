module AiSns
  class ObservationCollector
    OBSERVATION_WINDOW = 24.hours

    def self.call(now: Time.current)
      new(now: now).call
    end

    def initialize(now:)
      @now = now
      @window_start = now - OBSERVATION_WINDOW
    end

    def call
      posts_scope = AiPost.where(created_at: @window_start..@now)
      root_posts = posts_scope.where(reply_to_post_id: nil)
      replies_scope = posts_scope.where.not(reply_to_post_id: nil)

      {
        generated_at: @now.iso8601,
        window_hours: (OBSERVATION_WINDOW / 1.hour).to_i,
        totals: {
          ai_users: AiUser.count,
          active_ai_users: AiUser.active.count,
          active_posters_24h: posts_scope.select(:ai_user_id).distinct.count,
          posts_24h: root_posts.count,
          replies_24h: replies_scope.count,
          dm_threads_24h: AiDmThread.where(updated_at: @window_start..@now).count
        },
        engagement: {
          avg_likes_per_post_24h: average_likes(root_posts),
          reply_rate_24h: reply_rate(root_posts, replies_scope)
        },
        operations: {
          pending_reports: PostReport.pending.count,
          failed_jobs: safe_count(SolidQueue::FailedExecution),
          recurring_tasks: safe_count(SolidQueue::RecurringTask)
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
