class PostMotivationCalculateJob < ApplicationJob
  include JobErrorHandling

  queue_as :low
  sidekiq_options retry: 1, dead: false if respond_to?(:sidekiq_options)

  def perform
    AiUser.joins(:ai_daily_states)
          .where(ai_daily_states: { date: Date.current })
          .find_each(batch_size: 100) do |ai|
      daily_state = ai.ai_daily_states.find_by(date: Date.current)
      next unless daily_state

      score = Daily::PostMotivationCalculator.calculate(ai, daily_state)
      daily_state.update!(post_motivation: score)
    rescue => e
      Rails.logger.error("PostMotivationCalculateJob failed for ai_id=#{ai.id}: #{e.message}")
      next
    end
  end
end
