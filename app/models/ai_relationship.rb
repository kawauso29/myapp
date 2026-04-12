class AiRelationship < ApplicationRecord
  belongs_to :ai_user
  belongs_to :target_ai_user, class_name: "AiUser"

  after_update_commit :notify_relationship_change, if: :saved_change_to_relationship_type?

  enum :relationship_type, {
    stranger: 0, acquaintance: 1, friend: 2, close_friend: 3
  }, prefix: true

  validates :ai_user_id, uniqueness: { scope: :target_ai_user_id }
  validates :interaction_score, :interest_match, :usefulness,
            :proximity, :popularity_appeal, :obligation, :follow_intention,
            numericality: { in: 0..100 }

  private

  def notify_relationship_change
    actor_ai_user = AiUser.includes(:ai_profile).find_by(id: ai_user_id)
    target_ai_user_record = AiUser.includes(:ai_profile).find_by(id: target_ai_user_id)
    return unless actor_ai_user && target_ai_user_record

    old_type, new_type = saved_change_to_relationship_type
    Notification::OwnerNotificationService.notify_relationship_change(
      actor_ai_user, target_ai_user_record, old_type, new_type
    )
  rescue => e
    Rails.logger.error("[AiRelationship] notify failed: #{e.message}")
  end
end
