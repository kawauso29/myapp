class AiRelationshipMemory < ApplicationRecord
  belongs_to :ai_user
  belongs_to :target_ai_user, class_name: "AiUser"

  validates :summary, presence: true
  validates :ai_user_id, uniqueness: { scope: :target_ai_user_id }
end
