module Admin
  # 週次 PDCA ループ用の KPI 計算サービス
  # 利用可能な DB データからユーザー価値指標を集計する
  class KpiService
    WIP_LIMIT = 2

    def self.weekly_metrics
      now = Time.current
      week_ago  = 7.days.ago
      month_ago = 30.days.ago

      total_posts   = AiPost.count
      posts_week    = AiPost.where("created_at >= ?", week_ago).count
      replies_week  = AiPost.where("created_at >= ?", week_ago).where.not(reply_to_post_id: nil).count
      conv_rate     = posts_week > 0 ? (replies_week.to_f / posts_week * 100).round(1) : 0.0

      # リテンション: 30日以上前に登録したユーザーのうち今週アクティブな割合
      registered_30d_ago = User.where("created_at < ?", month_ago).count
      wau_from_old_users = registered_30d_ago > 0 ? (
        UserAiLike.where("created_at >= ?", week_ago)
                  .joins("INNER JOIN users ON users.id = user_ai_likes.user_id")
                  .where("users.created_at < ?", month_ago)
                  .select(:user_id).distinct.count
      ) : 0
      retention_30d_pct = registered_30d_ago > 0 ? (wau_from_old_users.to_f / registered_30d_ago * 100).round(1) : nil

      {
        collected_at: now.iso8601,
        users: {
          total:         User.count,
          new_this_week: User.where("created_at >= ?", week_ago).count,
          paid:          User.where(plan: %i[light premium]).count,
          # WAU: 今週いいねしたユニークユーザー数（アクティビティ代理指標）
          wau:           UserAiLike.where("created_at >= ?", week_ago).select(:user_id).distinct.count,
          # 30日リテンション: 30日以上前登録ユーザーが今週もアクティブな割合（%）
          retention_30d_pct: retention_30d_pct
        },
        posts: {
          total:                total_posts,
          this_week:            posts_week,
          replies_this_week:    replies_week,
          conversation_rate_pct: conv_rate
        },
        engagement: {
          user_likes_this_week: UserAiLike.where("created_at >= ?", week_ago).count,
          total_favorites:      UserFavoriteAi.count,
          active_dm_threads:    AiDmThread.where("last_message_at >= ?", week_ago).count
        },
        ai_social: {
          friend_plus_relationships: AiRelationship.where(relationship_type: %i[friend close_friend]).count,
          total_relationships:       AiRelationship.count,
          active_ais:                AiUser.active.count
        }
      }
    rescue => e
      Rails.logger.error("KpiService#weekly_metrics failed: #{e.message}")
      { error: e.message, collected_at: Time.current.iso8601 }
    end

    def self.wip_count
      Admin::AiSnsPlanService.items.count { |_, v| v["status"] == "in_progress" }
    end

    def self.wip_limit
      WIP_LIMIT
    end

    def self.wip_exceeded?
      wip_count >= WIP_LIMIT
    end
  end
end
