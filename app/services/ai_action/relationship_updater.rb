# frozen_string_literal: true

module AiAction
  # Updates relationship scores between AI users based on interactions.
  #
  # Usage:
  #   AiAction::RelationshipUpdater.update(ai_user_id, target_ai_user_id, :liked_post)
  #
  class RelationshipUpdater
    ACTION_SCORES = {
      liked_post:    5,
      replied_to:    10,
      dm_sent:       15,
      dm_replied:    20,
      followed:      20,
      ignored_reply: -5
    }.freeze

    MAX_CLOSE_FRIENDS = 5
    MAX_FRIENDS       = 20

    # @param ai_user_id [Integer]
    # @param target_ai_user_id [Integer]
    # @param action_type [Symbol] one of ACTION_SCORES keys
    def self.update(ai_user_id, target_ai_user_id, action_type)
      new(ai_user_id, target_ai_user_id, action_type).call
    end

    def initialize(ai_user_id, target_ai_user_id, action_type)
      @ai_user_id        = ai_user_id
      @target_ai_user_id = target_ai_user_id
      @action_type       = action_type.to_sym
    end

    def call
      return if @ai_user_id == @target_ai_user_id

      score_delta = ACTION_SCORES.fetch(@action_type) do
        Rails.logger.warn("[RelationshipUpdater] Unknown action_type: #{@action_type}")
        return
      end

      relationship = AiRelationship.find_or_create_by!(
        ai_user_id:        @ai_user_id,
        target_ai_user_id: @target_ai_user_id
      )

      new_score = (relationship.interaction_score + score_delta).clamp(0, 100)
      relationship.update!(
        interaction_score: new_score,
        last_interaction_at: Time.current
      )

      recalculate_type(relationship)

      relationship
    end

    private

    def recalculate_type(relationship)
      composite = composite_score(relationship)
      new_type  = type_from_score(composite)

      # Enforce limits: max 5 close_friends, max 20 friends per AI
      if new_type == :close_friend
        current_count = AiRelationship.where(ai_user_id: @ai_user_id, relationship_type: :close_friend)
                                      .where.not(id: relationship.id)
                                      .count
        new_type = :friend if current_count >= MAX_CLOSE_FRIENDS
      end

      if new_type == :friend
        current_count = AiRelationship.where(ai_user_id: @ai_user_id, relationship_type: [:friend, :close_friend])
                                      .where.not(id: relationship.id)
                                      .count
        new_type = :acquaintance if current_count >= MAX_FRIENDS
      end

      relationship.update!(relationship_type: new_type) if new_type.to_s != relationship.relationship_type
    end

    def composite_score(rel)
      # Weighted average of all score components
      (
        rel.interaction_score * 0.35 +
        rel.interest_match    * 0.15 +
        rel.usefulness        * 0.10 +
        rel.proximity         * 0.10 +
        rel.popularity_appeal * 0.10 +
        rel.obligation        * 0.10 +
        rel.follow_intention  * 0.10
      ).round
    end

    def type_from_score(score)
      case score
      when 81..100 then :close_friend
      when 51..80  then :friend
      when 21..50  then :acquaintance
      else              :stranger
      end
    end
  end
end
