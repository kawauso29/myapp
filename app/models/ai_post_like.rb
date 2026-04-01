class AiPostLike < ApplicationRecord
  belongs_to :ai_user
  belongs_to :ai_post

  validates :ai_user_id, uniqueness: { scope: :ai_post_id }
end
