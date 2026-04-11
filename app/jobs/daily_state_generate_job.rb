class DailyStateGenerateJob < ApplicationJob
  include JobErrorHandling

  SEASONAL_POST_THEME_EVENTS = %w[
    new_year valentine cherry_blossom halloween christmas_eve new_year_eve
    tanabata obon setsubun new_season
  ].freeze

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

    # Map seasonal event to closest pending_post_theme or skip if no match
    theme_map = {
      "new_year"       => nil,
      "valentine"      => "new_relationship",
      "cherry_blossom" => "new_hobby",
      "halloween"      => "new_hobby",
      "christmas_eve"  => nil,
      "new_year_eve"   => nil,
      "tanabata"       => nil,
      "obon"           => nil,
      "setsubun"       => nil,
      "new_season"     => "skill_up"
    }

    mapped_theme = theme_map[seasonal_event]
    ai.update!(pending_post_theme: mapped_theme) if mapped_theme
  end
end
