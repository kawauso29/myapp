class DailyStateGenerateJob < ApplicationJob
  include JobErrorHandling

  SEASONAL_POST_THEME_EVENTS = (
    Events::EventCalendar::EVENT_THEME_MAP.select { |_, v| v.present? }.keys
  ).freeze

  queue_as :low

  def perform
    AiUser.where(is_active: true).find_each(batch_size: 100) do |ai|
      next if ai.ai_daily_states.exists?(date: Date.current)

      state = Daily::DailyStateGenerator.generate(ai)
      apply_seasonal_post_theme(ai, state)
    rescue => e
      Rails.logger.error("DailyStateGenerateJob failed for ai_id=#{ai.id}: #{e.message}")
      next
    end
  end

  private

  def apply_seasonal_post_theme(ai, state)
    return unless state.today_events.any?

    seasonal_event = state.today_events.find { |ev| SEASONAL_POST_THEME_EVENTS.include?(ev) }
    return unless seasonal_event

    # Only override if no pending theme already set
    return if ai.pending_post_theme.present?

    mapped_theme = Events::EventCalendar.theme_for(seasonal_event, ai_user: ai)
    ai.update!(pending_post_theme: mapped_theme) if mapped_theme
  end
end
