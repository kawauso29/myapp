module JobErrorHandling
  extend ActiveSupport::Concern

  included do
    around_perform do |job, block|
      block.call
    rescue Anthropic::RateLimitError => e
      handle_rate_limit(e)
      raise

    rescue Anthropic::APIError => e
      if e.respond_to?(:status) && e.status >= 500
        Rails.logger.error("[#{job.class.name}] Claude API Server Error: #{e.message}")
        raise
      else
        Rails.logger.error("[#{job.class.name}] Claude API Client Error: #{e.message}")
      end

    rescue ActiveRecord::RecordNotUnique => e
      Rails.logger.warn("[#{job.class.name}] Duplicate record: #{e.message}")

    rescue => e
      Rails.logger.error("[#{job.class.name}] Unexpected error: #{e.class} #{e.message}")
      raise
    end
  end

  private

  def handle_rate_limit(error)
    wait_seconds = 60
    Rails.logger.warn("Rate limited. Waiting #{wait_seconds}s...")
    sleep(wait_seconds)
  end
end
