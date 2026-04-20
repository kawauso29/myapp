# Automatically discard stale UnknownJobClassError failures on boot.
#
# After a deploy, SolidQueue may briefly fail to resolve job classes
# (due to Bootsnap cache rebuild, process fork timing, etc.), creating
# FailedExecution records. If the class is now loadable, the failure
# was transient and can be safely discarded.
#
# This runs twice:
#   - 5 seconds after boot: catches failures created during the boot window
#   - 65 seconds after boot: catches failures from the first recurring-job
#     cycle (~5 min cron) if the class wasn't loaded yet when it fired

Rails.application.config.after_initialize do
  next unless defined?(SolidQueue) && Rails.env.production?

  cleanup_proc = lambda do |label|
    discarded = 0
    SolidQueue::FailedExecution
      .where("error LIKE ?", "%UnknownJobClassError%")
      .includes(:job)
      .find_each do |fe|
        job = fe.job
        next unless job

        # Extract the job class name
        job_class_name = job.class_name
        if job_class_name == "ActiveJob::QueueAdapters::SolidQueueAdapter::JobWrapper"
          args = job.arguments
          args = args.first if args.is_a?(Array)
          job_class_name = args["job_class"] || args[:job_class] if args.is_a?(Hash)
        end

        # If the class is now loadable, the failure was transient → discard
        if job_class_name.present? && job_class_name.safe_constantize
          fe.discard
          discarded += 1
        end
      rescue StandardError => e
        Rails.logger.warn("[SolidQueueBootCleanup] Error processing fe_id=#{fe.id}: #{e.message}")
      end

    if discarded > 0
      Rails.logger.info("[SolidQueueBootCleanup] #{label}: Discarded #{discarded} transient UnknownJobClassError failures")
    end
  rescue StandardError => e
    Rails.logger.warn("[SolidQueueBootCleanup] #{label} failed: #{e.message}")
  end

  # Use a thread to avoid blocking boot
  Thread.new do
    sleep 5 # Wait for SolidQueue to finish initialization
    cleanup_proc.call("boot+5s")

    sleep 60 # Wait for the first recurring-job cycle after boot (~5 min cron)
    cleanup_proc.call("boot+65s")
  end
end
