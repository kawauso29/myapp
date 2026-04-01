class DailyStateGenerateJob < ApplicationJob
  include JobErrorHandling

  queue_as :low
  sidekiq_options retry: 1, dead: false if respond_to?(:sidekiq_options)

  def perform
    AiUser.where(is_active: true).find_each(batch_size: 100) do |ai|
      next if ai.ai_daily_states.exists?(date: Date.current)

      Daily::DailyStateGenerator.generate(ai)
    rescue => e
      Rails.logger.error("DailyStateGenerateJob failed for ai_id=#{ai.id}: #{e.message}")
      next
    end
  end
end
