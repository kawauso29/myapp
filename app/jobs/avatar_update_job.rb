# frozen_string_literal: true

# Spec section 14: Daily avatar state update
# Schedule: daily at 00:00 JST
# Queue: low
# API calls: none (zero cost)
class AvatarUpdateJob < ApplicationJob
  include JobErrorHandling

  queue_as :low
  sidekiq_options retry: 1, dead: false if respond_to?(:sidekiq_options)

  # --- Expression mapping ---
  MOOD_TO_EXPRESSION = {
    "positive"      => :smile,
    "neutral"       => :normal,
    "negative"      => :sad,
    "very_negative" => :annoyed
  }.freeze

  # --- Season-based outfit mapping ---
  # outfit_top / outfit_bottom are integer columns; we define seasonal defaults
  # 0=casual_top, 1=light_top, 2=short_sleeve, 3=layers, 4=coat, 5=formal_top, 6=business_top
  # 0=casual_bottom, 1=shorts, 2=jeans, 3=formal_bottom, 4=skirt
  SEASON_OUTFITS = {
    spring: { top: 1, bottom: 0 },  # light tops, casual bottom
    summer: { top: 2, bottom: 1 },  # short sleeves, shorts
    autumn: { top: 3, bottom: 2 },  # layers, jeans
    winter: { top: 4, bottom: 2 }   # coats, jeans
  }.freeze

  # Life event overrides for outfit
  EVENT_OUTFIT_OVERRIDES = {
    "marriage"         => { top: 5, bottom: 3 },  # formal
    "new_relationship" => { top: 5, bottom: 3 },  # formal
    "new_hobby"        => { top: 0, bottom: 0 },  # casual
    "promotion"        => { top: 6, bottom: 3 },  # business
    "job_change"       => { top: 6, bottom: 3 }   # business
  }.freeze

  # Hair length enum values for reference
  HAIR_LENGTHS = %w[very_short short medium long very_long].freeze

  # Body type enum values
  BODY_TYPES = %w[slim normal_body slightly_chubby chubby].freeze

  BODY_UPDATE_INTERVAL_DAYS = 90

  def perform
    Rails.logger.info("[AvatarUpdateJob] Starting avatar updates")

    AiUser.where(is_active: true).find_each(batch_size: 100) do |ai|
      avatar = ai.ai_avatar_state
      next unless avatar

      daily_state = ai.today_state

      update_expression(avatar, daily_state) if daily_state
      update_hair(ai, avatar)
      update_outfit(ai, avatar)
      update_body_type(ai, avatar)
    rescue => e
      Rails.logger.error("[AvatarUpdateJob] Failed for ai_id=#{ai.id}: #{e.message}")
      next
    end

    Rails.logger.info("[AvatarUpdateJob] Completed")
  end

  private

  # ---- Expression (from daily_state mood) ----
  def update_expression(avatar, daily_state)
    expression = MOOD_TO_EXPRESSION[daily_state.mood] || :normal
    avatar.update!(expression: expression)
  end

  # ---- Hair growth + haircut decision ----
  def update_hair(ai, avatar)
    grow_hair(avatar)
    maybe_haircut(ai, avatar)
  end

  def grow_hair(avatar)
    return unless avatar.last_haircut_at

    days = (Date.current - avatar.last_haircut_at).to_i
    stages_grown = days / 3
    return if stages_grown <= 0

    current_index = HAIR_LENGTHS.index(avatar.hair_length) || 0
    new_index     = [current_index + stages_grown, HAIR_LENGTHS.length - 1].min
    avatar.update!(hair_length: HAIR_LENGTHS[new_index])
  end

  def maybe_haircut(ai, avatar)
    return unless %w[long very_long].include?(avatar.hair_length)

    # Base chance: 15% per day when long, 30% when very_long
    base_chance = avatar.hair_length == "very_long" ? 0.30 : 0.15

    # Personality modifier: higher self_expression = more likely to cut (keep tidy)
    personality = ai.ai_personality
    if personality
      modifier = case personality.self_expression
                 when "very_high" then 1.5
                 when "high"      then 1.2
                 when "normal"    then 1.0
                 when "low"       then 0.8
                 when "very_low"  then 0.6
                 else 1.0
                 end
      base_chance *= modifier
    end

    return unless rand < base_chance

    avatar.update!(hair_length: :very_short, last_haircut_at: Date.current)
    Rails.logger.info("[AvatarUpdateJob] ai_id=#{ai.id} got a haircut")
  end

  # ---- Outfit update (season + life events) ----
  def update_outfit(ai, avatar)
    season = current_season
    outfit = SEASON_OUTFITS[season].dup

    # Check for recent life events that override outfit
    recent_event = ai.ai_life_events.where(fired_at: 7.days.ago..).order(fired_at: :desc).first
    if recent_event && EVENT_OUTFIT_OVERRIDES.key?(recent_event.event_type)
      outfit = EVENT_OUTFIT_OVERRIDES[recent_event.event_type].dup
    end

    avatar.update!(outfit_top: outfit[:top], outfit_bottom: outfit[:bottom])
  end

  def current_season
    month = Date.current.month
    case month
    when 3, 4, 5   then :spring
    when 6, 7, 8   then :summer
    when 9, 10, 11 then :autumn
    else                 :winter
    end
  end

  # ---- Body type update (every 90 days) ----
  def update_body_type(ai, avatar)
    last_update = avatar.last_body_update_at || avatar.created_at.to_date
    return if (Date.current - last_update).to_i < BODY_UPDATE_INTERVAL_DAYS

    current_index = BODY_TYPES.index(avatar.body_type) || 1

    # Determine direction based on activity level heuristic
    # More posts + interactions = more active = trend toward slim
    recent_post_count = ai.ai_posts.where(created_at: 90.days.ago..).count
    active_relationships = ai.ai_relationships.where("interaction_score > ?", 30).count

    activity_level = recent_post_count + (active_relationships * 5)

    direction = if activity_level > 50
                  -1  # trending slimmer (more active)
                elsif activity_level < 10
                  1   # trending chubbier (less active)
                else
                  [-1, 0, 0, 1].sample  # mostly stable with small random drift
                end

    new_index = (current_index + direction).clamp(0, BODY_TYPES.length - 1)
    avatar.update!(body_type: BODY_TYPES[new_index], last_body_update_at: Date.current)

    if new_index != current_index
      Rails.logger.info(
        "[AvatarUpdateJob] ai_id=#{ai.id} body_type changed: #{BODY_TYPES[current_index]} -> #{BODY_TYPES[new_index]}"
      )
    end
  end
end
