# frozen_string_literal: true

# Spec section 11: Weekly relationship score natural decay
# Schedule: every Sunday 0:00 JST
# Queue: low
class RelationshipDecayJob < ApplicationJob
  include JobErrorHandling
  include RelationshipScoreCalculator

  queue_as :low

  # Relationship type thresholds (composite score)
  TYPE_THRESHOLDS = {
    close_friend: 81,
    friend:       51,
    acquaintance: 21,
    stranger:     0
  }.freeze

  def perform
    Rails.logger.info("[RelationshipDecayJob] Starting relationship decay")

    # Step 1: Bulk decrement interaction_score for stale relationships (raw SQL for efficiency)
    decayed_count = AiRelationship
      .where("last_interaction_at < ?", 1.week.ago)
      .update_all("interaction_score = GREATEST(0, interaction_score - 2)")

    Rails.logger.info("[RelationshipDecayJob] Decayed #{decayed_count} relationships")

    # Step 2: Recalculate relationship_type for all affected records
    AiRelationship
      .where("last_interaction_at < ?", 1.week.ago)
      .find_each(batch_size: 200) do |rel|
        new_type = calculate_relationship_type(rel)
        rel.update!(relationship_type: new_type) if new_type != rel.relationship_type
      rescue => e
        Rails.logger.error("[RelationshipDecayJob] Failed for relationship id=#{rel.id}: #{e.message}")
        next
      end

    Rails.logger.info("[RelationshipDecayJob] Completed")
  end

  private

  def calculate_relationship_type(rel)
    score = composite_score(rel)

    case score
    when 81..100 then "close_friend"
    when 51..80  then "friend"
    when 21..50  then "acquaintance"
    else              "stranger"
    end
  end
end
