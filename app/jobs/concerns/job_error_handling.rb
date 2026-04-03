module JobErrorHandling
  extend ActiveSupport::Concern

  included do
    around_perform do |job, block|
      block.call
    rescue ActiveRecord::RecordNotUnique => e
      Rails.logger.warn("[#{job.class.name}] Duplicate record: #{e.message}")

    rescue => e
      if e.class.name&.include?("RateLimit")
        Rails.logger.warn("[#{job.class.name}] Rate limited. Waiting 60s...")
        sleep(60)
        raise
      elsif e.class.name&.include?("APIError") || e.message.include?("API error")
        Rails.logger.error("[#{job.class.name}] LLM API Error: #{e.class} #{e.message}")
        raise
      else
        Rails.logger.error("[#{job.class.name}] Unexpected error: #{e.class} #{e.message}")
        raise
      end
    end
  end
end
