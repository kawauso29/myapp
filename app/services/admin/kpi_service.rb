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
        },
        # Phase 2 補強 / 穴③: 顧客フィードバック KPI の素材。
        # `kpi:customer_feedback` は「直近 7 日のネガティブ feedback 件数の少なさ」を
        # 0..100 のスコアに正規化して投入する（lower is better のため reverse_score で変換）。
        customer_feedback: customer_feedback_metrics(week_ago),
        # `kpi:company_revenue_growth` は「先月→今月の paid ユーザー増加率（%）」を代理値とする。
        # 真の MRR は Stripe 連携が必要なため、現時点では paid ユーザー数の前月比を用いる。
        company_revenue: company_revenue_metrics
      }
    rescue => e
      Rails.logger.error("KpiService#weekly_metrics failed: #{e.message}")
      { error: e.message, collected_at: Time.current.iso8601 }
    end

    # 顧客フィードバック関連の集計（Phase 2 補強 / 穴③）。
    # CustomerFeedbackLedger 未デプロイ環境でも安全に動くよう defined? でガードする。
    def self.customer_feedback_metrics(week_ago)
      return { total_this_week: 0, negative_this_week: 0, satisfaction_score: nil } unless defined?(CustomerFeedbackLedger)

      total = CustomerFeedbackLedger.where("received_at >= ?", week_ago).count
      negative = CustomerFeedbackLedger.where("received_at >= ?", week_ago)
                                       .where("categorization ->> 'sentiment' ILIKE ?", "negative")
                                       .count
      # satisfaction_score: ネガティブ率を 0..100 の「満足度」に反転（負が無ければ 100）。
      satisfaction_score = if total.positive?
                             (((total - negative).to_f / total) * 100).round(1)
      else
                             # フィードバック自体がない場合は nil（KPI 評価対象外として扱う）
                             nil
      end
      { total_this_week: total, negative_this_week: negative, satisfaction_score: satisfaction_score }
    rescue => e
      Rails.logger.warn("KpiService#customer_feedback_metrics failed: #{e.message}")
      { total_this_week: 0, negative_this_week: 0, satisfaction_score: nil }
    end

    # 売上成長 KPI の代理値（Phase 2 補強 / 穴③）。
    # 真の MRR は Stripe Webhook 経由の集計に差し替える前提のため、現時点は paid ユーザー数の
    # 前月比成長率（%）で暫定計算する。
    def self.company_revenue_metrics
      now = Time.current
      this_month_start = now.beginning_of_month
      last_month_start = (now - 1.month).beginning_of_month

      paid_now  = User.where(plan: %i[light premium]).count
      paid_last = User.where(plan: %i[light premium]).where("created_at < ?", this_month_start).count
      growth_pct = paid_last.positive? ? (((paid_now - paid_last).to_f / paid_last) * 100).round(2) : nil

      {
        paid_users: paid_now,
        paid_users_last_month: paid_last,
        growth_pct: growth_pct,
        last_month_started_at: last_month_start.iso8601
      }
    rescue => e
      Rails.logger.warn("KpiService#company_revenue_metrics failed: #{e.message}")
      { paid_users: 0, paid_users_last_month: 0, growth_pct: nil }
    end

    def self.wip_count
      Admin::AiSnsPlanService.stats[:in_progress]
    end

    def self.wip_limit
      WIP_LIMIT
    end

    def self.wip_exceeded?
      wip_count >= WIP_LIMIT
    end
  end
end
