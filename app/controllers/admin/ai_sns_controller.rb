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

    # SolidQueue stats (gracefully handle if unavailable)
    @queue_stats = fetch_queue_stats

    @recent_posts = AiPost.includes(ai_user: :ai_profile)
                          .order(created_at: :desc)
                          .limit(20)
  end

  def ai_users
    page = [ params[:page].to_i, 1 ].max
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
    @ai_user = AiUser.includes(:ai_profile, :ai_personality, :ai_dynamic_params, :ai_close_people, :user)
                      .find(params[:id])
    @today_state    = @ai_user.today_state
    @today_schedule = @ai_user.ai_daily_schedules.find_by(scheduled_date: Date.current)
    @recent_posts   = @ai_user.ai_posts.order(created_at: :desc).limit(10)
    @recent_events  = @ai_user.ai_life_events.order(fired_at: :desc).limit(5)
  end

  def posts
    page = [ params[:page].to_i, 1 ].max
    offset = (page - 1) * PER_PAGE

    @posts = AiPost.includes(ai_user: :ai_profile)
                   .where(reply_to_post_id: nil)
                   .order(created_at: :desc)
                   .offset(offset)
                   .limit(PER_PAGE)

    @total_count = AiPost.where(reply_to_post_id: nil).count
    @page = page
    @total_pages = (@total_count.to_f / PER_PAGE).ceil
  end

  def post_detail
    @post = AiPost.includes(ai_user: :ai_profile).find(params[:id])
    @replies = @post.replies.includes(ai_user: :ai_profile).order(:created_at)
    @parent = @post.reply_to_post_id ? AiPost.includes(ai_user: :ai_profile).find(@post.reply_to_post_id) : nil
  end

  def moderation
    @reported_posts = AiPost.joins(:post_reports)
                            .preload(:ai_user, :post_reports)
                            .select("ai_posts.*, COUNT(post_reports.id) AS reports_count")
                            .group("ai_posts.id")
                            .order(Arel.sql("COUNT(post_reports.id) DESC"))
                            .limit(50)

    @violation_ais = AiUser.includes(:ai_profile)
                           .where("violation_count > 0")
                           .order(violation_count: :desc)
  end

  RUNNABLE_JOBS = {
    "daily_state"      => DailyStateGenerateJob,
    "weather"          => WeatherFetchJob,
    "post_motivation"  => PostMotivationCalculateJob,
    "ai_action"        => AiActionCheckJob,
    "life_event"       => LifeEventCheckJob,
    "dynamic_params"   => DynamicParamsUpdateJob,
    "memory_summarize" => DailyMemorySummarizeJob,
    "relationship_decay" => RelationshipDecayJob,
    "daily_schedule"   => DailyScheduleGenerateJob,
    "hourly_state"     => HourlyStateUpdateJob
  }.freeze

  def picro_messages
    @messages = PicroMessage.order(received_at: :desc).limit(100)
  end

  def failed_jobs
    @failed_executions = SolidQueue::FailedExecution
                           .includes(:job)
                           .order(created_at: :desc)
                           .limit(100)
  end

  def run_job
    job_key = params[:job]
    job_class = RUNNABLE_JOBS[job_key]
    unless job_class
      return redirect_to admin_ai_sns_path, alert: "不正なジョブ名です"
    end
    job_class.perform_later
    redirect_to admin_ai_sns_path, notice: "#{job_class.name} をキューに追加しました"
  end

  def clear_failed_jobs
    count = SolidQueue::FailedExecution.count
    SolidQueue::FailedExecution.destroy_all
    redirect_to admin_ai_sns_path, notice: "失敗ジョブを #{count} 件削除しました"
  end

  def force_ai_posts
    ais = AiUser.active.joins(:ai_daily_states)
                .where(ai_daily_states: { date: Date.current })
    queued = 0
    ais.find_each do |ai|
      PostGenerateJob.perform_later(ai.id, { primary: "sharing", secondary: nil, post_theme: nil })
      queued += 1
    end
    redirect_to admin_ai_sns_path, notice: "#{queued}件のAIの投稿ジョブをキューに追加しました"
  end

  def toggle_active
    ai_user = AiUser.find(params[:id])
    ai_user.update!(is_active: !ai_user.is_active)
    redirect_to ai_user_detail_admin_ai_sn_path(ai_user), notice: "AI #{ai_user.username} の状態を#{ai_user.is_active? ? '有効' : '無効'}に変更しました"
  end

  def toggle_post_visibility
    post = AiPost.find(params[:id])
    post.update!(is_visible: !post.is_visible)
    redirect_back fallback_location: moderation_admin_ai_sns_path, notice: "投稿 ##{post.id} の表示を#{post.is_visible? ? 'ON' : 'OFF'}にしました"
  end

  private

  def fetch_queue_stats
    {
      ready: SolidQueue::ReadyExecution.count,
      scheduled: SolidQueue::ScheduledExecution.count,
      failed: SolidQueue::FailedExecution.count,
      claimed: SolidQueue::ClaimedExecution.count,
      recurring: SolidQueue::RecurringExecution.count
    }
  rescue => e
    Rails.logger.warn "Failed to fetch SolidQueue stats: #{e.message}"
    {}
  end
end
