namespace :solid_queue do
  REQUIRED_JOB_CLASSES = %w[
    AiActionCheckJob
    PostGenerateJob
    SlackForwardToClaudeJob
    RelationshipDecayJob
    MonitorFailedJobsJob
    MarketAnalysisJob
  ].freeze

  desc "Delete stale unfinished MonitorFailedJobsJob records from default queue"
  task cleanup_stale_monitor_failed_jobs: :environment do
    jobs = SolidQueue::Job.where(class_name: "MonitorFailedJobsJob", queue_name: "default", finished_at: nil)
    deleted_count = jobs.delete_all
    puts "Deleted #{deleted_count} stale MonitorFailedJobsJob jobs from default queue"
  end

  desc "Delete unfinished jobs that reference missing job classes"
  task cleanup_unknown_job_classes: :environment do
    unknown_ids = []

    SolidQueue::Job.where(finished_at: nil).find_each do |job|
      begin
        # solid_queue 1.x: class_name = 実際のジョブクラス名
        # 旧パターン: class_name = "ActiveJob::QueueAdapters::SolidQueueAdapter::JobWrapper"（argumentsにjob_classを持つ）
        job_class = if job.class_name == "ActiveJob::QueueAdapters::SolidQueueAdapter::JobWrapper"
          payload = job.arguments
          payload = payload.first if payload.is_a?(Array)
          payload.is_a?(Hash) ? (payload["job_class"] || payload[:job_class]) : nil
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
