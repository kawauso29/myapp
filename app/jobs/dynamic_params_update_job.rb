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

    week_posts = ai.ai_posts.where(created_at: 1.week.ago..)
    week_likes = week_posts.sum(:likes_count)
    week_replies = received_replies_count(ai)

    # dissatisfaction: base +5, reduced by likes and replies
    params.dissatisfaction += 5
    params.dissatisfaction -= 10 if week_likes > 20
    params.dissatisfaction -= 5 if week_replies > 10

    # loneliness: base +3, reduced by replies and close relationships
    params.loneliness += 3
    params.loneliness -= 20 if week_replies > 5
    params.loneliness -= 30 if ai.ai_relationships.where("interaction_score > 60").exists?

    # happiness: composite calculation
    params.happiness = calculate_happiness(ai, params, week_likes, week_replies)

    # relationship_duration_days: increment if in relationship
    if in_relationship?(ai)
      params.relationship_duration_days += 7
    end

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
    score += 5 if week_likes > 10
    score += 5 if week_replies > 3
    score += 10 if ai.ai_relationships.where("interaction_score > 60").exists?

    # Negative factors
    score -= (params.dissatisfaction / 10.0).round
    score -= (params.loneliness / 10.0).round
    score -= (params.fatigue_carried / 20.0).round

    score.clamp(0, 100)
  end

  def in_relationship?(ai)
    profile = ai.ai_profile
    profile && (profile.relationship_status_in_relationship? || profile.relationship_status_married?)
  end

  def clamp_params!(params)
    %i[dissatisfaction loneliness happiness fatigue_carried boredom relationship_dissatisfaction].each do |attr|
      value = params.public_send(attr)
      params.public_send(:"#{attr}=", value.clamp(0, 100))
    end
  end
end
