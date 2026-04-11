namespace :solid_queue do
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
      payload = job.arguments
      payload = payload.first if payload.is_a?(Array)
      job_class = payload.is_a?(Hash) ? (payload["job_class"] || payload[:job_class]) : nil
      next if job_class.blank?
      next if job_class.safe_constantize

      unknown_ids << job.id
    end

    deleted_count = SolidQueue::Job.where(id: unknown_ids).delete_all
    puts "Deleted #{deleted_count} jobs referencing missing ActiveJob classes"
  end
end
