namespace :solid_queue do
  desc "Delete stale unfinished MonitorFailedJobsJob records from default queue"
  task cleanup_stale_monitor_failed_jobs: :environment do
    jobs = SolidQueue::Job.where(class_name: "MonitorFailedJobsJob", queue_name: "default", finished_at: nil)
    deleted_count = jobs.delete_all
    puts "Deleted #{deleted_count} stale MonitorFailedJobsJob jobs from default queue"
  end
end
