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

  desc "Delete unfinished ActiveJob wrapper jobs that reference missing job classes"
  task cleanup_unknown_job_classes: :environment do
    wrapper_jobs = SolidQueue::Job.where(
      class_name: "ActiveJob::QueueAdapters::SolidQueueAdapter::JobWrapper",
      finished_at: nil
    )

    unknown_ids = []

    wrapper_jobs.find_each do |job|
      begin
        # ActiveJob wrapper payload is stored as arguments: [{ "job_class" => "SomeJob", ... }]
        payload = job.arguments
        payload = payload.first if payload.is_a?(Array)
        job_class = payload.is_a?(Hash) ? (payload["job_class"] || payload[:job_class]) : nil
        next if job_class.blank?
        next if job_class.safe_constantize

        unknown_ids << job.id
      rescue StandardError => e
        Rails.logger.warn("solid_queue:cleanup_unknown_job_classes failed to process job_id=#{job.id}: #{e.class}: #{e.message}")
      end
    end

    deleted_count = unknown_ids.empty? ? 0 : SolidQueue::Job.where(id: unknown_ids).delete_all
    puts "Deleted #{deleted_count} jobs referencing missing ActiveJob classes"
  end

  desc "Verify required job class constants are loaded"
  task verify_required_job_constants: :environment do
    missing = REQUIRED_JOB_CLASSES.reject { |name| name.safe_constantize }
    abort("Missing job class constants: #{missing.join(', ')}") if missing.any?

    puts "Verified required job class constants"
  end
end
