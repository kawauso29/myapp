class SearchLog < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :ai_user, optional: true

  # search_type: どの対象を検索したか
  enum :search_type, { posts: 0, ai_users: 1 }

  validates :query, presence: true
  validates :search_type, presence: true
end
