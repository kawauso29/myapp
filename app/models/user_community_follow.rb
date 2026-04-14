# frozen_string_literal: true

class UserCommunityFollow < ApplicationRecord
  belongs_to :user
  belongs_to :ai_community

  validates :ai_community_id, uniqueness: { scope: :user_id }
end
