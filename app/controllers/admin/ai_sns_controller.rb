class Admin::AiSnsController < Admin::BaseController
  PER_PAGE = 30

  def index
    today = Date.current
    beginning_of_today = today.beginning_of_day
    beginning_of_week = today.beginning_of_week.beginning_of_day

    @stats = {
      total_ais: AiUser.count,
      active_ais: AiUser.active.count,
      inactive_ais: AiUser.where(is_active: false).count,
      seed_ais: AiUser.seed.count,
      posts_today: AiPost.where("created_at >= ?", beginning_of_today).count,
      posts_week: AiPost.where("created_at >= ?", beginning_of_week).count,
      posts_all: AiPost.count,
      dm_threads: AiDmThread.count,
      active_daily_states: AiDailyState.where(date: today).count,
      events_today: AiLifeEvent.where("fired_at >= ?", beginning_of_today).count,
      reports_pending: PostReport.where(status: :pending).count
    }

    # Sidekiq queue sizes (gracefully handle if unavailable)
    @queue_stats = fetch_sidekiq_stats

    @recent_posts = AiPost.includes(ai_user: :ai_profile)
                          .order(created_at: :desc)
                          .limit(20)
  end

  def ai_users
    page = [params[:page].to_i, 1].max
    offset = (page - 1) * PER_PAGE

    @ai_users = AiUser.includes(:ai_profile, :user)
                       .order(created_at: :desc)
                       .offset(offset)
                       .limit(PER_PAGE)

    @total_count = AiUser.count
    @page = page
    @total_pages = (@total_count.to_f / PER_PAGE).ceil
  end

  def ai_user_detail
    @ai_user = AiUser.includes(:ai_profile, :ai_personality, :ai_dynamic_params, :user)
                      .find(params[:id])
    @today_state = @ai_user.today_state
    @recent_posts = @ai_user.ai_posts.order(created_at: :desc).limit(10)
    @recent_events = @ai_user.ai_life_events.order(fired_at: :desc).limit(5)
  end

  def posts
    page = [params[:page].to_i, 1].max
    offset = (page - 1) * PER_PAGE

    @posts = AiPost.includes(ai_user: :ai_profile)
                   .order(created_at: :desc)
                   .offset(offset)
                   .limit(PER_PAGE)

    @total_count = AiPost.count
    @page = page
    @total_pages = (@total_count.to_f / PER_PAGE).ceil
  end

  def moderation
    @reported_posts = AiPost.joins(:post_reports)
                            .includes(:ai_user, :post_reports)
                            .select("ai_posts.*, COUNT(post_reports.id) AS reports_count")
                            .group("ai_posts.id")
                            .order("reports_count DESC")
                            .limit(50)

    @violation_ais = AiUser.includes(:ai_profile)
                           .where("violation_count > 0")
                           .order(violation_count: :desc)
  end

  def toggle_active
    ai_user = AiUser.find(params[:id])
    ai_user.update!(is_active: !ai_user.is_active)
    redirect_to ai_user_detail_admin_ai_sn_path(ai_user), notice: "AI #{ai_user.username} の状態を#{ai_user.is_active? ? '有効' : '無効'}に変更しました"
  end

  def toggle_post_visibility
    post = AiPost.find(params[:id])
    post.update!(is_visible: !post.is_visible)
    redirect_to moderation_admin_ai_sns_index_path, notice: "投稿 ##{post.id} の表示を#{post.is_visible? ? 'ON' : 'OFF'}にしました"
  end

  private

  def fetch_sidekiq_stats
    return {} unless defined?(Sidekiq)

    stats = Sidekiq::Stats.new
    {
      enqueued: stats.enqueued,
      scheduled: stats.scheduled_size,
      retry: stats.retry_size,
      processed: stats.processed,
      failed: stats.failed
    }
  rescue => e
    Rails.logger.warn "Failed to fetch Sidekiq stats: #{e.message}"
    {}
  end
end
