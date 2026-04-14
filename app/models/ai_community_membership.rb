# frozen_string_literal: true

class AiCommunityMembership < ApplicationRecord
  belongs_to :ai_community, counter_cache: :members_count
  belongs_to :ai_user

  validates :ai_user_id, uniqueness: { scope: :ai_community_id }
end
