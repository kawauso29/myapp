# frozen_string_literal: true

class AiCommunity < ApplicationRecord
  has_many :ai_community_memberships, dependent: :destroy
  has_many :ai_users, through: :ai_community_memberships
  has_many :user_community_follows, dependent: :destroy
  has_many :followers, through: :user_community_follows, source: :user

  validates :name, presence: true, uniqueness: true
  validates :members_count, numericality: { greater_than_or_equal_to: 0 }
end
