class LifeEventCheckJob < ApplicationJob
  include JobErrorHandling

  queue_as :low

  # Phase 1 events: cooldown_days, probability, trigger conditions, param changes
  # trigger: hash of { param_name => minimum_value } on AiDynamicParams
  # prerequisite: :none, :has_relationship, :is_employed, :is_sick
  # param_change: incremental changes applied to AiDynamicParams
  # param_reset: params set to an absolute value
  PHASE1_EVENTS = {
    job_change: {
      cooldown_days: 180,
      probability: 0.08,
      prerequisite: :is_employed,
      trigger: { dissatisfaction: 60 },
      param_change: { dissatisfaction: -40, boredom: -30 },
      param_reset: {}
    },
    relocation: {
      cooldown_days: 365,
      probability: 0.05,
      prerequisite: :none,
      trigger: { dissatisfaction: 50, loneliness: 40 },
      param_change: { loneliness: -20, dissatisfaction: -30 },
      param_reset: {}
    },
    promotion: {
      cooldown_days: 365,
      probability: 0.06,
      prerequisite: :is_employed,
      trigger: { happiness: 50 },
      param_change: { happiness: 20, dissatisfaction: -30 },
      param_reset: {}
    },
    new_relationship: {
      cooldown_days: 90,
      probability: 0.07,
      prerequisite: :is_single,
      trigger: { loneliness: 50 },
      param_change: { loneliness: -50, happiness: 20 },
      param_reset: { relationship_duration_days: 0, relationship_dissatisfaction: 0 }
    },
    breakup: {
      cooldown_days: 90,
      probability: 0.06,
      prerequisite: :has_relationship,
      trigger: { relationship_dissatisfaction: 60 },
      param_change: { loneliness: 30, happiness: -30 },
      param_reset: { relationship_duration_days: 0, relationship_dissatisfaction: 0 }
    },
    marriage: {
      cooldown_days: 730,
      probability: 0.03,
      prerequisite: :has_relationship,
      trigger: { happiness: 60, relationship_duration_days: 180 },
      param_change: { happiness: 30, loneliness: -30 },
      param_reset: {}
    },
    illness: {
      cooldown_days: 60,
      probability: 0.08,
      prerequisite: :none,
      trigger: { fatigue_carried: 50 },
      param_change: { happiness: -20, fatigue_carried: 20 },
      param_reset: {}
    },
    recovery: {
      cooldown_days: 30,
      probability: 0.15,
      prerequisite: :is_sick,
      trigger: {},
      param_change: { happiness: 15, fatigue_carried: -30 },
      param_reset: {}
    },
    new_hobby: {
      cooldown_days: 60,
      probability: 0.10,
      prerequisite: :none,
      trigger: { boredom: 50 },
      param_change: { boredom: -40, happiness: 10 },
      param_reset: {}
    },
    skill_up: {
      cooldown_days: 90,
      probability: 0.08,
      prerequisite: :none,
      trigger: { boredom: 30 },
      param_change: { boredom: -20, happiness: 10, dissatisfaction: -10 },
      param_reset: {}
    }
  }.freeze

  def perform
    Rails.logger.info("[LifeEventCheckJob] Starting weekly life event check")

    AiUser.active.find_each do |ai|
      check_events_for(ai)
    rescue => e
      Rails.logger.error("[LifeEventCheckJob] Failed for ai_id=#{ai.id}: #{e.class} #{e.message}")
      next
    end
  end

  private

  def check_events_for(ai)
    params = ai.ai_dynamic_params
    return unless params

    PHASE1_EVENTS.each do |event_key, config|
      # a. Cooldown check
      last_fired = ai.ai_life_events.where(event_type: event_key).maximum(:fired_at)
      next if last_fired && last_fired > config[:cooldown_days].days.ago

      # b. Prerequisite check
      next unless prerequisite_met?(ai, config[:prerequisite])

      # c. Trigger condition check
      next unless trigger_met?(params, config[:trigger])

      # d. Probability check
      next unless rand < config[:probability]

      # e. Fire event (max 1 per AI per week)
      fire_event!(ai, event_key, config)
      break
    end
  end

  def prerequisite_met?(ai, prerequisite)
    case prerequisite
    when :none
      true
    when :is_employed
      profile = ai.ai_profile
      profile && (profile.occupation_type_employed? || profile.occupation_type_freelance?)
    when :is_single
      profile = ai.ai_profile
      profile && profile.relationship_status_single?
    when :has_relationship
      profile = ai.ai_profile
      profile && (profile.relationship_status_in_relationship? || profile.relationship_status_married?)
    when :is_sick
      today_state = ai.today_state
      today_state&.physical_sick?
    else
      true
    end
  end

  def trigger_met?(params, trigger)
    return true if trigger.blank?

    trigger.all? do |param_name, min_value|
      current_value = params.public_send(param_name)
      current_value >= min_value
    end
  end

  # Chains: parent event key → { chain_type, wait_days }
  CHAIN_EVENTS = {
    job_change:       { chain_type: "job_change_aftermath",  wait_days: 7  },
    breakup:          { chain_type: "breakup_recovery",      wait_days: 14 },
    illness:          { chain_type: "illness_recovery",      wait_days: 7  },
    marriage:         { chain_type: "marriage_bliss",        wait_days: 7  },
    relocation:       { chain_type: "relocation_settled",    wait_days: 14 }
  }.freeze

  def fire_event!(ai, event_key, config)
    Rails.logger.info("[LifeEventCheckJob] Firing #{event_key} for ai_id=#{ai.id}")

    # Create life event record
    life_event = ai.ai_life_events.create!(
      event_type: event_key,
      fired_at: Time.current
    )

    # Apply param changes
    apply_param_changes(ai, config[:param_change], config[:param_reset])

    # Set pending post theme
    ai.update!(pending_post_theme: event_key)

    # Save as long-term memory (Japanese, context-aware)
    ai.ai_long_term_memories.create!(
      content: life_event_memory_text(event_key, ai),
      memory_type: :life_event,
      importance: 4,
      occurred_on: Date.current
    )

    # Schedule chain event if defined
    if (chain = CHAIN_EVENTS[event_key])
      LifeEventChainJob
        .set(wait: chain[:wait_days].days)
        .perform_later(ai.id, chain[:chain_type], life_event.id)
      Rails.logger.info(
        "[LifeEventCheckJob] Scheduled chain=#{chain[:chain_type]} in #{chain[:wait_days]}d for ai_id=#{ai.id}"
      )
    end

    SlackNotifierService.notify(
      text: ":sparkles: *ライフイベント発生* @#{ai.username}",
      color: :warning,
      fields: [
        { title: "イベント", value: event_key.to_s },
        { title: "連鎖", value: CHAIN_EVENTS[event_key] ? "#{CHAIN_EVENTS[event_key][:wait_days]}日後に続きあり" : "なし" }
      ],
      channel: :jobs,
      service_id: "ai_sns"
    )
  end

  LIFE_EVENT_MEMORY_TEXTS = {
    job_change:       ->(ai) { "転職した。新しい職場での生活が始まった。" },
    relocation:       ->(ai) { "引越しをした。新しい場所での生活がスタートした。" },
    promotion:        ->(ai) { "昇進した。#{ai.ai_profile&.occupation}として認められた。" },
    new_relationship: ->(ai) { "新しい恋人ができた。胸が高鳴る毎日が始まった。" },
    breakup:          ->(ai) { "恋人と別れた。しばらくは気持ちの整理が必要そうだ。" },
    marriage:         ->(ai) { "結婚した。人生の大きな節目を迎えた。" },
    illness:          ->(ai) { "体調を崩して寝込んだ。無理のしすぎが原因かもしれない。" },
    recovery:         ->(ai) { "体調がようやく回復した。健康のありがたさを実感した。" },
    new_hobby:        ->(ai) { "新しい趣味を始めた。最近ずっと気になっていたことに挑戦した。" },
    skill_up:         ->(ai) { "新しいスキルを身につけた。少し自信がついた気がする。" }
  }.freeze

  def life_event_memory_text(event_key, ai)
    builder = LIFE_EVENT_MEMORY_TEXTS[event_key]
    builder ? builder.call(ai) : "#{event_key}が起きた。"
  end

  def apply_param_changes(ai, param_change, param_reset)
    params = ai.ai_dynamic_params
    return unless params

    # Apply absolute resets first
    param_reset.each do |key, value|
      params.public_send(:"#{key}=", value)
    end

    # Apply incremental changes
    param_change.each do |key, delta|
      current = params.public_send(key)
      new_value = (current + delta).clamp(0, 100)
      params.public_send(:"#{key}=", new_value)
    end

    params.save!
  end
end
