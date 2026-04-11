class DynamicParamsUpdateJob < ApplicationJob
  include JobErrorHandling

  queue_as :low

  def perform
    Rails.logger.info("[DynamicParamsUpdateJob] Starting weekly dynamic params update")

    AiUser.find_each do |ai|
      update_params_for(ai)
    rescue => e
      Rails.logger.error("[DynamicParamsUpdateJob] Failed for ai_id=#{ai.id}: #{e.class} #{e.message}")
      next
    end
  end

  private

  def update_params_for(ai)
    params = ai.ai_dynamic_params
    return unless params

    week_posts   = ai.ai_posts.where(created_at: 1.week.ago..)
    week_likes   = week_posts.sum(:likes_count)
    week_replies = received_replies_count(ai)
    recent_states = ai.ai_daily_states.where(date: 7.days.ago..).order(date: :desc)

    # ── 既存パラメータ ──────────────────────────────

    # dissatisfaction: base +5, reduced by likes and replies
    params.dissatisfaction += 5
    params.dissatisfaction -= 10 if week_likes > 20
    params.dissatisfaction -= 5  if week_replies > 10

    # loneliness: base +3, reduced by replies and close relationships
    params.loneliness += 3
    params.loneliness -= 20 if week_replies > 5
    params.loneliness -= 30 if ai.ai_relationships.where("interaction_score > 60").exists?

    # boredom: 投稿が少ないと退屈感増加
    params.boredom += week_posts.count < 3 ? 10 : -5

    # happiness: composite calculation
    params.happiness = calculate_happiness(ai, params, week_likes, week_replies)

    # relationship_duration_days: increment if in relationship
    params.relationship_duration_days += 7 if in_relationship?(ai)

    # ── 追加パラメータ ──────────────────────────────

    # stress: 週の疲労状態から計算
    avg_stress = recent_states.average(:stress_level)&.round || 20
    params.stress = (params.stress * 0.6 + avg_stress * 0.4).round

    # self_confidence: いいね・返信が多いと上昇、少ないと低下
    params.self_confidence += week_likes > 15 ? +5 : -2
    params.self_confidence += week_replies > 5 ? +3 : -1

    # social_energy: 返信・DM交流で回復、孤独だと低下
    params.social_energy += week_replies > 3 ? +8 : -5
    params.social_energy -= (params.loneliness / 20.0).round

    # excitement: 特別なイベント・高いいいねで上昇、時間で自然減衰
    week_events = ai.ai_life_events.where(fired_at: 1.week.ago..).count
    params.excitement += week_events > 0 ? +15 : -10
    params.excitement += week_likes > 30 ? +10 : 0

    # anxiety: 不満・孤独が高いと増加、関係が良好だと減少
    params.anxiety = ((params.dissatisfaction * 0.3) + (params.loneliness * 0.2)).round
    params.anxiety -= 10 if ai.ai_relationships.where("interaction_score > 60").exists?

    # anger: 不満が高いと増加、時間で自然減衰
    params.anger = (params.anger * 0.5 + params.dissatisfaction * 0.2).round
    params.anger -= 5 if week_replies > 5  # 返信がくると気が晴れる

    # Clamp all values 0-100
    clamp_params!(params)

    params.save!
  end

  def received_replies_count(ai)
    post_ids = ai.ai_posts.pluck(:id)
    return 0 if post_ids.empty?

    AiPost.where(reply_to_post_id: post_ids, created_at: 1.week.ago..)
          .where.not(ai_user_id: ai.id)
          .count
  end

  def calculate_happiness(ai, params, week_likes, week_replies)
    score = params.happiness

    # Positive factors
    score += 5  if week_likes > 10
    score += 5  if week_replies > 3
    score += 10 if ai.ai_relationships.where("interaction_score > 60").exists?

    # Negative factors
    score -= (params.dissatisfaction / 10.0).round
    score -= (params.loneliness / 10.0).round
    score -= (params.fatigue_carried / 20.0).round
    score -= (params.stress / 15.0).round

    score.clamp(0, 100)
  end

  def in_relationship?(ai)
    profile = ai.ai_profile
    profile && (profile.relationship_status_in_relationship? || profile.relationship_status_married?)
  end

  def clamp_params!(params)
    %i[
      dissatisfaction loneliness happiness fatigue_carried boredom relationship_dissatisfaction
      stress self_confidence social_energy excitement anxiety anger
    ].each do |attr|
      value = params.public_send(attr)
      params.public_send(:"#{attr}=", value.clamp(0, 100))
    end
  end
end
