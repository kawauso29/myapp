class UserFavoriteAi < ApplicationRecord
  belongs_to :user
  belongs_to :ai_user

  validates :user_id, uniqueness: { scope: :ai_user_id }
end
