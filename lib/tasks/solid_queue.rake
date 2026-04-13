namespace :solid_queue do
  REQUIRED_JOB_CLASSES = %w[
    AiActionCheckJob
    PostGenerateJob
    SlackForwardToClaudeJob
    RelationshipDecayJob
    MonitorFailedJobsJob
    MarketAnalysisJob
    WeatherFetchJob
    DailyScheduleGenerateJob
    DynamicParamsUpdateJob
    AiSnsAutonomousImprovementJob
    MilestoneCheckJob
    WeeklyKpiSnapshotJob
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
    rescue JSON::ParserError => e
      Rails.logger.warn("solid_queue:cleanup_stale_monitor_failed_jobs JSON parse failed: #{e.message}")
      nil
    end

    deleted_count = SolidQueue::Job.where(finished_at: nil, class_name: "MonitorFailedJobsJob").delete_all
    wrapper_job_ids = []

    SolidQueue::Job.where(finished_at: nil, class_name: "ActiveJob::QueueAdapters::SolidQueueAdapter::JobWrapper").find_each do |job|
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

  desc "Verify required job class constants are loaded"
  task verify_required_job_constants: :environment do
    missing = REQUIRED_JOB_CLASSES.reject { |name| name.safe_constantize }
    abort("Missing job class constants: #{missing.join(', ')}") if missing.any?

    puts "Verified required job class constants"
  end
end
