# Automatically discard stale UnknownJobClassError failures on boot.
#
# After a deploy, SolidQueue may briefly fail to resolve job classes
# (due to Bootsnap cache rebuild, process fork timing, etc.), creating
# FailedExecution records. If the class is now loadable, the failure
# was transient and can be safely discarded.
#
# This runs once at boot, cleaning up any stale failures from previous restarts.

Rails.application.config.after_initialize do
  next unless defined?(SolidQueue) && Rails.env.production?

  # Use a thread to avoid blocking boot
  Thread.new do
    sleep 5 # Wait for SolidQueue to finish initialization

    begin
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
        Rails.logger.info("[SolidQueueBootCleanup] Discarded #{discarded} transient UnknownJobClassError failures on boot")
      end
    rescue StandardError => e
      Rails.logger.warn("[SolidQueueBootCleanup] Boot cleanup failed: #{e.message}")
    end
  end
end
