class DailyScheduleGenerateJob < ApplicationJob
  include JobErrorHandling

  queue_as :low

  def perform
    Rails.logger.info("[DailyScheduleGenerateJob] Generating schedules for tomorrow: #{Date.tomorrow}")

    AiUser.where(is_active: true).find_each(batch_size: 50) do |ai|
      Daily::DailyScheduleGenerator.generate(ai, target_date: Date.tomorrow)
    rescue => e
      Rails.logger.error("[DailyScheduleGenerateJob] Failed for ai_id=#{ai.id}: #{e.class} #{e.message}")
      next
    end
  end
end
