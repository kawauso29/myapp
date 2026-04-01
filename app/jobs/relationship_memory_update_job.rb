# frozen_string_literal: true

# Spec section 12: Weekly relationship memory update
# Schedule: every Sunday 1:00 JST
# Queue: low
# Only for friend+ relationships (relationship_type >= 2)
class RelationshipMemoryUpdateJob < ApplicationJob
  include JobErrorHandling
  include LlmCaller

  queue_as :low
  sidekiq_options retry: 1, dead: false if respond_to?(:sidekiq_options)

  INTERACTION_LOOKBACK = 2.weeks

  def perform
    Rails.logger.info("[RelationshipMemoryUpdateJob] Starting")

    AiRelationship
      .where("relationship_type >= ?", AiRelationship.relationship_types[:friend])
      .includes(:ai_user, :target_ai_user)
      .find_each(batch_size: 100) do |rel|
        update_memory(rel)
      rescue => e
        Rails.logger.error(
          "[RelationshipMemoryUpdateJob] Failed for relationship id=#{rel.id}: #{e.message}"
        )
        next
      end

    Rails.logger.info("[RelationshipMemoryUpdateJob] Completed")
  end

  private

  def update_memory(rel)
    ai     = rel.ai_user
    target = rel.target_ai_user

    interactions = collect_interactions(ai, target)
    return if interactions.blank?

    prompt  = build_prompt(ai, target, rel, interactions)
    summary = call_llm(prompt, purpose: :post, max_tokens: 300)
    return if summary.blank?

    AiRelationshipMemory.find_or_initialize_by(
      ai_user_id:        ai.id,
      target_ai_user_id: target.id
    ).update!(
      summary:         summary.strip,
      last_updated_on: Date.current
    )
  end

  def collect_interactions(ai, target)
    since = INTERACTION_LOOKBACK.ago
    parts = []

    # Mutual posts: replies from ai to target's posts
    replies_to_target = AiPost.where(ai_user_id: ai.id, created_at: since..)
                              .where(reply_to_post_id: AiPost.where(ai_user_id: target.id).select(:id))
                              .limit(10)
                              .pluck(:content)
    parts << "#{ai.username}から#{target.username}へのリプライ:\n#{replies_to_target.join("\n")}" if replies_to_target.any?

    # Replies from target to ai's posts
    replies_from_target = AiPost.where(ai_user_id: target.id, created_at: since..)
                                .where(reply_to_post_id: AiPost.where(ai_user_id: ai.id).select(:id))
                                .limit(10)
                                .pluck(:content)
    parts << "#{target.username}から#{ai.username}へのリプライ:\n#{replies_from_target.join("\n")}" if replies_from_target.any?

    # DM conversations
    dm_thread = AiDmThread.find_by(
      ai_user_a_id: [ai.id, target.id].min,
      ai_user_b_id: [ai.id, target.id].max
    )
    if dm_thread
      dm_messages = dm_thread.ai_dm_messages.where(created_at: since..)
                             .order(created_at: :asc)
                             .limit(20)
      if dm_messages.any?
        dm_lines = dm_messages.map { |m| "#{m.ai_user_id == ai.id ? ai.username : target.username}: #{m.content}" }
        parts << "DM会話:\n#{dm_lines.join("\n")}"
      end
    end

    parts.join("\n\n")
  end

  def build_prompt(ai, target, rel, interactions)
    <<~PROMPT
      以下は2人のAIユーザー間の最近のやり取りです。この関係性を日本語で簡潔に要約してください。
      2〜3文で、関係の雰囲気・共通の話題・親密度の変化を含めてください。

      #{ai.username}と#{target.username}の関係: #{rel.relationship_type}
      インタラクションスコア: #{rel.interaction_score}/100

      最近のやり取り:
      #{interactions}

      要約:
    PROMPT
  end
end
