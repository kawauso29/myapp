namespace :solid_queue do
  REQUIRED_JOB_CLASSES = %w[
    AiActionCheckJob
    PostGenerateJob
    DmCheckJob
    SlackForwardToClaudeJob
    RelationshipDecayJob
    MonitorFailedJobsJob
    MarketAnalysisJob
    WeatherFetchJob
    DailyScheduleGenerateJob
    DynamicParamsUpdateJob
    MilestoneCheckJob
    WeeklyKpiSnapshotJob
    WeeklyDeptLedgerRunJob
    MonthlyOpsLedgerRunJob
    DailyLedgerRunJob
    TicketOverdueCheckJob
    ImprovementDetectorJob
    PicroCheckJob
    DefeatAnalysisJob
    MonthlyReportJob
    DailyStateGenerateJob
    PostMotivationCalculateJob
    HourlyStateUpdateJob
    DailyMemorySummarizeJob
    ExpiredMemoryCleanupJob
    LifeEventCheckJob
    QuarterlyReviewLedgerRunJob
    AnnualPlanLedgerRunJob
    HrEvaluationRunJob
    PortfolioRebalanceRunJob
    ImprovementDetectorJob
    ImprovementResolverJob
    ImprovementEscalationJob
    ExperimentAutoDeciderJob
    SlaSweepJob
    KpiAutoCollectJob
    KpiGradeEvaluateJob
    StopConditionMonitorJob
    EffectivenessRecalcJob
    PlannerJob
    TicketIssueSyncJob
    UiCheckLedgerRunJob
    HeartbeatSchedulerJob
  ].freeze
  STALE_RECURRING_JOB_CLASSES = %w[
    AiActionCheckJob
    MonitorFailedJobsJob
    MarketAnalysisJob
  ].freeze
  WRAPPER_CLEANUP_BATCH_SIZE = 500

  desc "Delete stale unfinished MonitorFailedJobsJob records from all queues"
  task cleanup_stale_monitor_failed_jobs: :environment do
    extract_wrapper_job_class = lambda do |raw_arguments|
      payload = raw_arguments
      payload = JSON.parse(payload) if payload.is_a?(String)
      payload = payload.first if payload.is_a?(Array)
      if payload.is_a?(Hash)
        payload["job_class"] || payload[:job_class]
      else
        nil
      end
    rescue StandardError => e
      Rails.logger.warn("solid_queue:cleanup_stale_monitor_failed_jobs argument parse failed: #{e.class}: #{e.message}")
      nil
    end

    deleted_count = SolidQueue::Job.where(finished_at: nil, class_name: "MonitorFailedJobsJob").delete_all
    wrapper_job_ids = []

    SolidQueue::Job.where(finished_at: nil, class_name: "ActiveJob::QueueAdapters::SolidQueueAdapter::JobWrapper")
      .select(:id, :arguments)
      .find_each do |job|
      job_class = extract_wrapper_job_class.call(job.arguments)
      next unless job_class == "MonitorFailedJobsJob"

      wrapper_job_ids << job.id
      next unless wrapper_job_ids.size >= WRAPPER_CLEANUP_BATCH_SIZE

      deleted_count += SolidQueue::Job.where(id: wrapper_job_ids).delete_all
      wrapper_job_ids.clear
    end

    deleted_count += SolidQueue::Job.where(id: wrapper_job_ids).delete_all unless wrapper_job_ids.empty?
    puts "Deleted #{deleted_count} stale MonitorFailedJobsJob jobs from all queues"
  end

  desc "Delete unfinished jobs that reference missing job classes"
  task cleanup_unknown_job_classes: :environment do
    unknown_ids = []

    SolidQueue::Job.where(finished_at: nil).find_each do |job|
      begin
        extract_wrapper_job_class = lambda do |raw_arguments|
          payload = raw_arguments
          if payload.is_a?(String)
            payload = JSON.parse(payload)
          end
          payload = payload.first if payload.is_a?(Array)

          if payload.is_a?(Hash)
            payload["job_class"] || payload[:job_class]
          end
        rescue JSON::ParserError => e
          Rails.logger.warn("solid_queue:cleanup_unknown_job_classes JSON parse failed for job_id=#{job.id}: #{e.message}")
          nil
        end

        # solid_queue 1.x: class_name = 実際のジョブクラス名
        # 旧パターン: class_name = "ActiveJob::QueueAdapters::SolidQueueAdapter::JobWrapper"（argumentsにjob_classを持つ）
        job_class = if job.class_name == "ActiveJob::QueueAdapters::SolidQueueAdapter::JobWrapper"
          extract_wrapper_job_class.call(job.arguments)
        else
          job.class_name
        end

        next if job_class.blank?
        next if job_class.safe_constantize

        unknown_ids << job.id
      rescue StandardError => e
        Rails.logger.warn("solid_queue:cleanup_unknown_job_classes failed to process job_id=#{job.id}: #{e.class}: #{e.message}")
      end
    end

    deleted_count = unknown_ids.empty? ? 0 : SolidQueue::Job.where(id: unknown_ids).delete_all
    puts "Deleted #{deleted_count} jobs referencing missing job classes"
  end

  desc "Delete stale recurring jobs and failed records for recurring jobs that should always exist"
  task cleanup_stale_recurring_unknown_class_jobs: :environment do
    stale_job_ids = []

    extract_wrapper_job_class = lambda do |raw_arguments|
      payload = raw_arguments
      payload = JSON.parse(payload) if payload.is_a?(String)
      payload = payload.first if payload.is_a?(Array)
      payload["job_class"] || payload[:job_class] if payload.is_a?(Hash)
    rescue JSON::ParserError => e
      Rails.logger.warn("solid_queue:cleanup_stale_recurring_unknown_class_jobs JSON parse failed: #{e.message}")
      nil
    end

    cleanup_target_class_names = STALE_RECURRING_JOB_CLASSES + [ "ActiveJob::QueueAdapters::SolidQueueAdapter::JobWrapper" ]
    SolidQueue::Job.where(finished_at: nil, class_name: cleanup_target_class_names).find_each do |job|
      job_class = if job.class_name == "ActiveJob::QueueAdapters::SolidQueueAdapter::JobWrapper"
        extract_wrapper_job_class.call(job.arguments)
      else
        job.class_name
      end
      next unless STALE_RECURRING_JOB_CLASSES.include?(job_class)

      stale_job_ids << job.id
    end

    deleted_jobs_count = stale_job_ids.empty? ? 0 : SolidQueue::Job.where(id: stale_job_ids).delete_all

    class_filter_sql = STALE_RECURRING_JOB_CLASSES.map { "error LIKE ?" }.join(" OR ")
    class_filter_args = STALE_RECURRING_JOB_CLASSES.map { |class_name| "%#{class_name}%" }
    failed_executions = SolidQueue::FailedExecution
      .where("error LIKE ?", "%UnknownJobClassError%")
      .where([class_filter_sql, *class_filter_args])
    stale_failed_count = 0
    failed_executions.find_each do |execution|
      execution.discard
      stale_failed_count += 1
    rescue StandardError => e
      Rails.logger.warn("solid_queue:cleanup_stale_recurring_unknown_class_jobs discard failed id=#{execution.id}: #{e.message}")
    end

    puts "Deleted #{deleted_jobs_count} stale recurring jobs and discarded #{stale_failed_count} UnknownJobClassError failed executions"
  end

  desc "Discard FailedExecution records with ActiveJob::UnknownJobClassError (stale pre-deploy failures)"
  task discard_unknown_class_failed_executions: :environment do
    count = SolidQueue::FailedExecution.where("error LIKE ?", "%UnknownJobClassError%").count
    SolidQueue::FailedExecution.where("error LIKE ?", "%UnknownJobClassError%").find_each do |ex|
      ex.discard
    rescue StandardError => e
      Rails.logger.warn("solid_queue:discard_unknown_class_failed_executions failed for id=#{ex.id}: #{e.message}")
    end
    puts "Discarded #{count} FailedExecution records with UnknownJobClassError"
  end

  desc "Diagnose SolidQueue health (live processes, recurring tasks, recent activity). SLACK=1 to also notify Slack jobs channel."
  task diagnose: :environment do
    lines = []
    lines << "=== SolidQueue Diagnose @ #{Time.current.iso8601} (#{Rails.env}) ==="

    # 1) Live processes registered by the supervisor
    begin
      processes = SolidQueue::Process.order(:kind, :name).to_a
      lines << "[processes] count=#{processes.size}"
      kind_counts = processes.group_by(&:kind).transform_values(&:size)
      %w[Supervisor Dispatcher Worker Scheduler].each do |kind|
        lines << "  - #{kind}: #{kind_counts[kind] || 0}"
      end
      processes.each do |p|
        lines << "  · pid=#{p.pid} kind=#{p.kind} name=#{p.name} last_heartbeat_at=#{p.last_heartbeat_at}"
      end
      if (kind_counts["Scheduler"] || 0).zero?
        lines << "  !! WARNING: no Scheduler process running. Recurring tasks (config/recurring.yml) will NOT fire."
      end
    rescue StandardError => e
      lines << "[processes] ERROR: #{e.class}: #{e.message}"
    end

    # 2) Recurring tasks registered (DB side)
    begin
      tasks = SolidQueue::RecurringTask.order(:key).to_a
      lines << "[recurring_tasks] count=#{tasks.size}"
      tasks.first(50).each do |t|
        lines << "  · #{t.key} class=#{t.class_name} schedule=#{t.schedule}"
      end
      lines << "  ... (#{tasks.size - 50} more tasks omitted)" if tasks.size > 50
      if tasks.empty?
        lines << "  !! WARNING: no recurring tasks registered in DB. Scheduler may not have booted."
      end
    rescue StandardError => e
      lines << "[recurring_tasks] ERROR: #{e.class}: #{e.message}"
    end

    # 3) Recent recurring executions (last 60 minutes)
    begin
      window_start = 60.minutes.ago
      recent = SolidQueue::RecurringExecution.where("created_at >= ?", window_start).count
      lines << "[recurring_executions last_60min] count=#{recent}"
      last = SolidQueue::RecurringExecution.order(created_at: :desc).first
      lines << "  · most_recent_at=#{last&.created_at || 'none'} task_key=#{last&.task_key}"
      if recent.zero?
        lines << "  !! WARNING: no recurring executions in the last 60 minutes."
      end
    rescue StandardError => e
      lines << "[recurring_executions] ERROR: #{e.class}: #{e.message}"
    end

    # 4) Job throughput (last 24h)
    begin
      enqueued_24h = SolidQueue::Job.where("created_at >= ?", 24.hours.ago).count
      finished_24h = SolidQueue::Job.where("finished_at >= ?", 24.hours.ago).count
      pending = SolidQueue::Job.where(finished_at: nil).count
      failed_open = SolidQueue::FailedExecution.count
      lines << "[jobs last_24h] enqueued=#{enqueued_24h} finished=#{finished_24h} pending_total=#{pending} failed_executions_open=#{failed_open}"
      if enqueued_24h.zero?
        lines << "  !! WARNING: zero jobs enqueued in last 24h. SolidQueue scheduler is almost certainly stalled."
      end
    rescue StandardError => e
      lines << "[jobs] ERROR: #{e.class}: #{e.message}"
    end

    # 5) ENV sanity (mask secrets)
    %w[RAILS_ENV SOLID_QUEUE_IN_PUMA].each do |k|
      lines << "[env] #{k}=#{ENV[k].inspect}"
    end
    %w[SLACK_WEBHOOK_URL SLACK_WEBHOOK_URL_ERROR SLACK_WEBHOOK_URL_JOBS].each do |k|
      lines << "[env] #{k}=#{ENV[k].present? ? 'set' : 'unset'}"
    end

    output = lines.join("\n")
    puts output

    if ENV["SLACK"] == "1"
      warnings = lines.count { |l| l.include?("!! WARNING") }
      color = warnings.positive? ? :danger : :success
      jobs_webhook_missing = ENV["SLACK_WEBHOOK_URL_JOBS"].blank?
      fallback_to_error = warnings.zero? && jobs_webhook_missing
      channel = warnings.positive? || fallback_to_error ? :error : :jobs
      # Reserve room for the closing code fence so truncation never breaks markdown.
      body_limit = 2500
      body = output.length > body_limit ? "#{output[0, body_limit - 20]}\n... (truncated)" : output
      fallback_note = fallback_to_error ? "\n(slack routing: jobs webhook is unset, fallback to error channel)" : ""
      SlackNotifierService.notify(
        text: ":mag: *SolidQueue diagnose* (warnings=#{warnings})#{fallback_note}\n```\n#{body}\n```",
        color: color,
        channel: channel
      )
    end
  end

  desc "Alert via Slack if SolidQueue appears stalled (no jobs enqueued in WINDOW_MINUTES, default 30)."
  task check_alive: :environment do
    window_minutes = ENV.fetch("WINDOW_MINUTES", "30").to_i
    threshold = window_minutes.minutes.ago

    enqueued = begin
      SolidQueue::Job.where("created_at >= ?", threshold).count
    rescue StandardError => e
      Rails.logger.error("[solid_queue:check_alive] query failed: #{e.message}")
      -1
    end

    scheduler_count = begin
      SolidQueue::Process.where(kind: "Scheduler").count
    rescue StandardError
      -1
    end

    if enqueued.zero? || scheduler_count.zero?
      reason = []
      reason << "no jobs enqueued in last #{window_minutes}min" if enqueued.zero?
      reason << "no Scheduler process alive" if scheduler_count.zero?
      msg = ":rotating_light: *SolidQueue stall detected* — #{reason.join(' / ')}"
      Rails.logger.error("[solid_queue:check_alive] #{msg}")
      SlackNotifierService.notify(
        text: msg,
        color: :danger,
        channel: :error,
        fields: [
          { title: "enqueued_in_window", value: enqueued.to_s },
          { title: "scheduler_processes", value: scheduler_count.to_s },
          { title: "window_minutes",     value: window_minutes.to_s },
          { title: "host",               value: (ENV["HOSTNAME"] || `hostname`.strip).to_s }
        ]
      )
      exit 1
    else
      puts "OK: enqueued=#{enqueued} (last #{window_minutes}min), schedulers=#{scheduler_count}"
    end
  end

  desc "Verify required job class constants are loaded"
  task verify_required_job_constants: :environment do
    missing = REQUIRED_JOB_CLASSES.reject { |name| name.safe_constantize }
    abort("Missing job class constants: #{missing.join(', ')}") if missing.any?

    puts "Verified required job class constants"
  end
end
