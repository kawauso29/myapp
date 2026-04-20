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
#
# NOTE: Uses a local `retried` variable (not thread-local) to guard against
# a single retry. Using thread-local + ensure caused the guard to be cleared
# before the outer rescue could see it, potentially causing infinite retries.

module ActiveJobUnknownClassRetry
  def deserialize(job_data)
    retried = false
    begin
      super
    rescue ActiveJob::UnknownJobClassError => e
      # Re-raise if we already tried once to prevent infinite retries.
      # If a *different* exception type is raised (e.g. from eager_load! itself),
      # it will propagate naturally without being caught by this rescue clause —
      # that is intentional; we only retry for UnknownJobClassError.
      raise if retried

      retried = true
      Rails.logger.warn(
        "[ActiveJobUnknownClassRetry] #{e.message}, forcing eager_load and retrying..."
      )
      Rails.application.eager_load!
      retry
    end
  end
end

ActiveJob::Base.singleton_class.prepend(ActiveJobUnknownClassRetry)
