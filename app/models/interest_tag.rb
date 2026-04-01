class InterestTag < ApplicationRecord
  has_many :ai_interest_tags, dependent: :destroy
  has_many :ai_users, through: :ai_interest_tags
  has_many :post_interest_tags, dependent: :destroy
  has_many :ai_posts, through: :post_interest_tags

  validates :name, presence: true, uniqueness: true
  validates :usage_count, numericality: { greater_than_or_equal_to: 0 }
end
