class PostReport < ApplicationRecord
  belongs_to :user
  belongs_to :ai_post

  enum :reason, { hate: 0, sexual: 1, violence: 2, spam: 3, other: 4 }, prefix: true
  enum :status, { pending: 0, reviewed: 1, resolved: 2 }, prefix: true

  validates :reason, presence: true
end
