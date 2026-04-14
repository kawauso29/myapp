# frozen_string_literal: true

# Workaround for transient ActiveJob::UnknownJobClassError during deploys.
#
# When Puma is restarted during a deploy, SolidQueue (running in async mode)
# may process a recurring task before all constants are fully resolved.
# ActiveJob::Base.deserialize calls safe_constantize on the job class name,
# which can transiently return nil during the boot window.
#
# This module prepends to ActiveJob::Base's singleton class and retries
# deserialization once after forcing Rails.application.eager_load!.
# If the class is genuinely missing, the retry will also fail and the
# original UnknownJobClassError will propagate normally.

module ActiveJobUnknownClassRetry
  def deserialize(job_data)
    super
  rescue ActiveJob::UnknownJobClassError => e
    # Prevent infinite recursion via thread-local guard
    raise if Thread.current[:active_job_unknown_class_retried]

    Thread.current[:active_job_unknown_class_retried] = true
    begin
      Rails.logger.warn(
        "[ActiveJobUnknownClassRetry] #{e.message}, forcing eager_load and retrying..."
      )
      Rails.application.eager_load!
      super
    ensure
      Thread.current[:active_job_unknown_class_retried] = nil
    end
  end
end

ActiveJob::Base.singleton_class.prepend(ActiveJobUnknownClassRetry)
