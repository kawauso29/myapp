class AiRelationship < ApplicationRecord
  belongs_to :ai_user
  belongs_to :target_ai_user, class_name: "AiUser"

  enum :relationship_type, {
    stranger: 0, acquaintance: 1, friend: 2, close_friend: 3
  }, prefix: true

  validates :ai_user_id, uniqueness: { scope: :target_ai_user_id }
  validates :interaction_score, :interest_match, :usefulness,
            :proximity, :popularity_appeal, :obligation, :follow_intention,
            numericality: { in: 0..100 }
end
