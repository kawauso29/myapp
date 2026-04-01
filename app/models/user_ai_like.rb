class UserAiLike < ApplicationRecord
  belongs_to :user
  belongs_to :ai_post

  validates :user_id, uniqueness: { scope: :ai_post_id }
end
