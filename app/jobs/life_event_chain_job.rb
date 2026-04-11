# frozen_string_literal: true

# Fires a follow-up (chain) life event N days after the parent event.
# Enqueued by LifeEventCheckJob with a delay via set(wait: N.days).
class LifeEventChainJob < ApplicationJob
  include JobErrorHandling

  queue_as :low

  # chain_type → { event_type, post_theme, memory_text, param_change }
  CHAIN_DEFINITIONS = {
    "job_change_aftermath" => {
      post_theme:   :skill_up,
      memory_text:  "新しい職場にも慣れてきた。人間関係や仕事のペースが少しずつ掴めてきた。",
      param_change: { dissatisfaction: -10, happiness: 10 }
    },
    "breakup_recovery" => {
      post_theme:   :new_hobby,
      memory_text:  "別れてからしばらく経つ。気持ちが少しずつ前向きになってきた。",
      param_change: { loneliness: -15, happiness: 10 }
    },
    "illness_recovery" => {
      post_theme:   :recovery,
      memory_text:  "体調がだいぶ回復してきた。健康って当たり前じゃないと実感した。",
      param_change: { fatigue_carried: -20, happiness: 10 }
    },
    "marriage_bliss" => {
      post_theme:   :new_relationship,
      memory_text:  "結婚してから日常が少し変わった。二人での生活が新鮮で温かい。",
      param_change: { happiness: 10, loneliness: -10 }
    },
    "relocation_settled" => {
      post_theme:   :new_hobby,
      memory_text:  "引越し先の街にも慣れてきた。お気に入りの場所が少しずつ増えてきた。",
      param_change: { loneliness: -10, dissatisfaction: -10 }
    }
  }.freeze

  def perform(ai_user_id, chain_type, parent_event_id)
    ai = AiUser.active.find_by(id: ai_user_id)
    return unless ai

    definition = CHAIN_DEFINITIONS[chain_type]
    return unless definition

    Rails.logger.info("[LifeEventChainJob] Firing chain=#{chain_type} for ai_id=#{ai_user_id}")

    # Create the chained life event (reuse parent's event_type or closest match)
    parent_event = AiLifeEvent.find_by(id: parent_event_id)
    event_type = definition[:post_theme] || parent_event&.event_type || :skill_up

    life_event = ai.ai_life_events.create!(
      event_type:      event_type,
      fired_at:        Time.current,
      parent_event_id: parent_event_id,
      chain_type:      chain_type
    )

    # Apply param changes
    apply_param_changes(ai, definition[:param_change])

    # Set pending post theme
    ai.update!(pending_post_theme: definition[:post_theme])

    # Save memory
    ai.ai_long_term_memories.create!(
      content:     definition[:memory_text],
      memory_type: :life_event,
      importance:  3,
      occurred_on: Date.current
    )

    Rails.logger.info("[LifeEventChainJob] Completed chain=#{chain_type} life_event_id=#{life_event.id}")
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("[LifeEventChainJob] Failed chain=#{chain_type} ai_id=#{ai_user_id}: #{e.message}")
  end

  private

  def apply_param_changes(ai, param_change)
    return if param_change.blank?

    params = ai.ai_dynamic_params
    return unless params

    param_change.each do |key, delta|
      current = params.public_send(key)
      params.public_send(:"#{key}=", (current + delta).clamp(0, 100))
    end
    params.save!
  end
end
