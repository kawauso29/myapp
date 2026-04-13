require "net/http"

class Admin::AiSnsController < Admin::BaseController
  PER_PAGE = 30
  AI_SNS_JOB_CLASS_NAMES = %w[
    DailyStateGenerateJob
    WeatherFetchJob
    PostMotivationCalculateJob
    AiActionCheckJob
    LifeEventCheckJob
    DynamicParamsUpdateJob
    DailyMemorySummarizeJob
    RelationshipDecayJob
    DailyScheduleGenerateJob
    HourlyStateUpdateJob
    PostGenerateJob
    MonitorFailedJobsJob
    MilestoneCheckJob
  ].freeze
  AI_SNS_RECURRING_TASK_KEYS = %w[
    daily_state_generate
    daily_state_heal
    weather_fetch
    post_motivation_calculate
    ai_action_check
    daily_memory_summarize
    expired_memory_cleanup
    life_event_check
    dynamic_params_update
    milestone_check
    relationship_decay
    daily_schedule_generate
    hourly_state_update
    monitor_failed_jobs
  ].freeze
  PERSONALITY_DEFAULTS = {
    sociability: 3,
    post_frequency: 3,
    active_time_peak: 3,
    need_for_approval: 3,
    emotional_range: 3,
    risk_tolerance: 3,
    self_expression: 3,
    drinking_frequency: 2,
    self_esteem: 3,
    empathy: 3,
    jealousy: 2,
    curiosity: 3,
    patience: 3,
    optimism: 3,
    creativity: 3,
    independence: 3,
    trustfulness: 3,
    competitiveness: 3,
    sensitivity: 3,
    humor: 3,
    nostalgia_tendency: 2,
    perfectionism: 3,
    stubbornness: 3,
    generosity: 3,
    follow_philosophy: 1,
    primary_purpose: 0
  }.freeze
  DYNAMIC_PARAMS_DEFAULTS = {
    dissatisfaction: 10,
    loneliness: 10,
    happiness: 50,
    fatigue_carried: 0,
    boredom: 10,
    relationship_dissatisfaction: 0,
    relationship_duration_days: 0,
    stress: 10,
    self_confidence: 50,
    social_energy: 50,
    excitement: 20,
    anxiety: 10,
    anger: 0
  }.freeze

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
    @ai_sns_recurring_tasks = fetch_ai_sns_recurring_tasks
    @recent_ai_sns_jobs = fetch_recent_ai_sns_jobs
    @upcoming_ai_sns_scheduled_jobs = fetch_upcoming_ai_sns_scheduled_jobs

    @recent_posts = AiPost.includes(ai_user: :ai_profile)
                          .order(created_at: :desc)
                          .limit(20)

    @kpi_trend = KpiSnapshot.weekly_trend(periods: 8)
    @kpi_metrics = Admin::KpiService.weekly_metrics
    @ai_sns_plan_stats = Admin::AiSnsPlanService.stats
    @ai_sns_plan_next = Admin::AiSnsPlanService.next_item
    @ai_sns_plan_items = Admin::AiSnsPlanService.items_by_priority
    @last_manual_job_status = fetch_last_manual_job_status
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
    "daily_state"      => { klass: DailyStateGenerateJob },
    "weather"          => { klass: WeatherFetchJob },
    "post_motivation"  => { klass: PostMotivationCalculateJob },
    "ai_action"        => { klass: AiActionCheckJob },
    "ai_action_like"   => { klass: AiActionCheckJob, args: [ "like" ] },
    "ai_action_reply"  => { klass: AiActionCheckJob, args: [ "reply" ] },
    "ai_action_post"   => { klass: AiActionCheckJob, args: [ "post" ] },
    "ai_action_dm"     => { klass: AiActionCheckJob, args: [ "dm" ] },
    "life_event"       => { klass: LifeEventCheckJob },
    "dynamic_params"   => { klass: DynamicParamsUpdateJob },
    "memory_summarize" => { klass: DailyMemorySummarizeJob },
    "relationship_decay" => { klass: RelationshipDecayJob },
    "daily_schedule"   => { klass: DailyScheduleGenerateJob },
    "hourly_state"     => { klass: HourlyStateUpdateJob },
    "milestone_check"  => { klass: MilestoneCheckJob }
  }.freeze

  def picro_messages
    redirect_to admin_picro_notifications_path
  end

  def trigger_ai_sns_plan
    token = ENV["DEPLOY_TOKEN"]
    return redirect_to admin_ai_sns_path, alert: "DEPLOY_TOKEN が設定されていません" unless token.present?

    item_id = params[:item_id].presence || ""
    res = github_dispatch_request(
      token: token,
      workflow: "ai_sns_plan.yml",
      body: { ref: "main", inputs: { item_id: item_id } }.to_json
    )

    if res.code == "204"
      msg = item_id.present? ? "[#{item_id}] の実装依頼を Copilot に送りました。" : "次の優先項目の実装依頼を Copilot に送りました。"
      redirect_to admin_ai_sns_path, notice: "#{msg} GitHub Actions を確認してください。"
    else
      redirect_to admin_ai_sns_path, alert: "ワークフロー起動失敗 (#{res.code}): #{res.body}"
    end
  rescue => e
    redirect_to admin_ai_sns_path, alert: "エラー: #{e.message}"
  end

  def failed_jobs
    @failed_executions = SolidQueue::FailedExecution
                           .includes(:job)
                           .order(created_at: :desc)
                           .limit(100)
    @failed_execution_rows = @failed_executions.map { |execution| build_failed_execution_row(execution) }
  end

  def run_job
    job_key = params[:job]
    job_config = RUNNABLE_JOBS[job_key]
    unless job_config
      return redirect_to admin_ai_sns_path, alert: "不正なジョブ名です"
    end

    job_class = job_config.fetch(:klass)
    job_args = job_config.fetch(:args, [])
    enqueued_job = job_class.perform_later(*job_args)
    save_last_manual_job!(job_class: job_class, job_key: job_key, active_job_id: enqueued_job.job_id)
    redirect_to admin_ai_sns_path, notice: "#{job_class.name} をキューに追加しました（ActiveJob ID: #{enqueued_job.job_id}）"
  rescue => e
    Rails.logger.error "Failed to enqueue admin manual job (#{job_key}): #{e.message}"
    redirect_to admin_ai_sns_path, alert: "ジョブ投入に失敗しました: #{e.message}"
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

  def backfill_ai_attributes
    result = perform_backfill_ai_attributes
    redirect_to admin_ai_sns_path, notice: "AI属性補完完了: profile日付=#{result[:profile_age_base_date]}件 / close_people日付=#{result[:close_people_age_base_date]}件 / personality作成=#{result[:personality_created]}件 / personality補完=#{result[:personality_fields_filled]}項目 / dynamic作成=#{result[:dynamic_params_created]}件 / dynamic補完=#{result[:dynamic_params_fields_filled]}項目 / avatar作成=#{result[:avatar_state_created]}件"
  rescue => e
    Rails.logger.error "Failed to backfill AI attributes: #{e.message}"
    redirect_to admin_ai_sns_path, alert: "AI属性補完に失敗しました: #{e.message}"
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

  def perform_backfill_ai_attributes
    result = {
      profile_age_base_date: 0,
      close_people_age_base_date: 0,
      personality_created: 0,
      personality_fields_filled: 0,
      dynamic_params_created: 0,
      dynamic_params_fields_filled: 0,
      avatar_state_created: 0
    }
    current_date = Date.current
    current_time = Time.current

    AiProfile.where(age_base_date: nil).where.not(age: nil).find_each do |profile|
      profile.update_columns(age_base_date: current_date, updated_at: current_time)
      result[:profile_age_base_date] += 1
    end

    AiClosePerson.where(age_base_date: nil).where.not(age: nil).find_each do |person|
      person.update_columns(age_base_date: current_date, updated_at: current_time)
      result[:close_people_age_base_date] += 1
    end

    AiUser.find_each do |ai_user|
      personality = ai_user.ai_personality
      unless personality
        personality = ai_user.create_ai_personality!
        result[:personality_created] += 1
      end

      dynamic_params = ai_user.ai_dynamic_params
      unless dynamic_params
        dynamic_params = ai_user.create_ai_dynamic_params!
        result[:dynamic_params_created] += 1
      end

      if ai_user.ai_avatar_state.nil?
        ai_user.create_ai_avatar_state!
        result[:avatar_state_created] += 1
      end

      missing_personality_fields = PERSONALITY_DEFAULTS.select { |field, _| personality.public_send(field).nil? }
      if missing_personality_fields.any?
        personality.update_columns(**missing_personality_fields, updated_at: current_time)
        result[:personality_fields_filled] += missing_personality_fields.size
      end

      missing_dynamic_param_fields = DYNAMIC_PARAMS_DEFAULTS.select { |field, _| dynamic_params.public_send(field).nil? }
      if missing_dynamic_param_fields.any?
        dynamic_params.update_columns(**missing_dynamic_param_fields, updated_at: current_time)
        result[:dynamic_params_fields_filled] += missing_dynamic_param_fields.size
      end
    end

    result
  end

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

  def fetch_ai_sns_recurring_tasks
    SolidQueue::RecurringTask.where(key: AI_SNS_RECURRING_TASK_KEYS).order(:key)
  rescue => e
    Rails.logger.warn "Failed to fetch AI SNS recurring tasks: #{e.message}"
    []
  end

  def fetch_recent_ai_sns_jobs
    jobs = SolidQueue::Job.where(class_name: AI_SNS_JOB_CLASS_NAMES)
                          .where.not(finished_at: nil)
                          .order(finished_at: :desc)
                          .limit(50)
    failed_job_ids = SolidQueue::FailedExecution.where(job_id: jobs.select(:id)).pluck(:job_id)
    jobs.map do |job|
      [ job, failed_job_ids.include?(job.id) ]
    end
  rescue => e
    Rails.logger.warn "Failed to fetch recent AI SNS jobs: #{e.message}"
    []
  end

  def fetch_upcoming_ai_sns_scheduled_jobs
    SolidQueue::ScheduledExecution.includes(:job)
                                  .joins(:job)
                                  .where("solid_queue_scheduled_executions.scheduled_at >= ?", Time.current)
                                  .where(solid_queue_jobs: { class_name: AI_SNS_JOB_CLASS_NAMES })
                                  .order("solid_queue_scheduled_executions.scheduled_at ASC")
                                  .limit(30)
  rescue => e
    Rails.logger.warn "Failed to fetch upcoming AI SNS scheduled jobs: #{e.message}"
    []
  end

  def save_last_manual_job!(job_class:, job_key:, active_job_id:)
    session[:admin_ai_sns_last_manual_job] = {
      job_class: job_class.name,
      job_key: job_key,
      active_job_id: active_job_id,
      triggered_at: Time.current.iso8601
    }
  end

  def fetch_last_manual_job_status
    raw = session[:admin_ai_sns_last_manual_job]
    return nil unless raw.respond_to?(:to_h)

    manual = raw.to_h.with_indifferent_access
    active_job_id = manual[:active_job_id]
    return nil if active_job_id.blank?

    job = SolidQueue::Job.find_by(active_job_id: active_job_id)
    return { manual: manual, status: :missing, job: nil, failed_execution: nil, error: nil } unless job

    failed_execution = SolidQueue::FailedExecution.find_by(job_id: job.id)
    status = if failed_execution
      :failed
    elsif job.finished_at.present?
      :success
    elsif SolidQueue::ClaimedExecution.exists?(job_id: job.id)
      :running
    elsif SolidQueue::ReadyExecution.exists?(job_id: job.id) || SolidQueue::ScheduledExecution.exists?(job_id: job.id)
      :queued
    else
      :unknown
    end

    {
      manual: manual,
      status: status,
      job: job,
      failed_execution: failed_execution,
      error: normalized_error_data(failed_execution&.error)
    }
  rescue => e
    Rails.logger.warn "Failed to fetch last manual job status: #{e.message}"
    nil
  end

  def build_failed_execution_row(execution)
    error_data = normalized_error_data(execution.error)
    {
      execution: execution,
      job_class_name: resolved_job_class_name(execution.job, error_data),
      exception_class: error_data["exception_class"].presence || "Unknown",
      message: error_data["message"].to_s,
      backtrace: Array(error_data["backtrace"]).first(5)
    }
  end

  def normalized_error_data(error)
    case error
    when Hash
      error.stringify_keys
    when String
      parsed = JSON.parse(error)
      parsed.is_a?(Hash) ? parsed.stringify_keys : { "message" => error }
    else
      if error.respond_to?(:to_h)
        error.to_h.stringify_keys
      else
        { "message" => error.to_s }
      end
    end
  rescue JSON::ParserError
    { "message" => error.to_s }
  end

  def resolved_job_class_name(job, error_data = {})
    return "unknown" unless job

    job_class_name = job.class_name
    return job_class_name unless job_class_name == "ActiveJob::QueueAdapters::SolidQueueAdapter::JobWrapper"

    payload = job.arguments
    payload = JSON.parse(payload) if payload.is_a?(String)
    payload = payload.first if payload.is_a?(Array)
    wrapper_job_class = payload["job_class"] || payload[:job_class] if payload.is_a?(Hash)
    wrapper_job_class.presence || extract_missing_class_name(error_data["message"].to_s) || job_class_name
  rescue JSON::ParserError
    extract_missing_class_name(error_data["message"].to_s) || job_class_name
  end

  def extract_missing_class_name(message)
    message.match(/class [`"]([^`"]+)[`"] doesn't exist/)&.captures&.first
  end

  def github_dispatch_request(token:, workflow:, body:)
    uri = URI("https://api.github.com/repos/kawauso29/myapp/actions/workflows/#{workflow}/dispatches")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = 15

    req = Net::HTTP::Post.new(uri.request_uri)
    req["Authorization"] = "Bearer #{token}"
    req["Accept"] = "application/vnd.github+json"
    req["X-GitHub-Api-Version"] = "2022-11-28"
    req["Content-Type"] = "application/json"
    req.body = body

    http.request(req)
  end
end
