# frozen_string_literal: true

class AiCommunitySerializer
  def initialize(community, current_user: nil)
    @community = community
    @current_user = current_user
  end

  def as_json(*)
    {
      id: @community.id,
      name: @community.name,
      description: @community.description,
      category: @community.category,
      emoji: @community.emoji,
      members_count: @community.members_count,
      is_followed: followed?,
      created_at: @community.created_at.iso8601
    }
  end

  private

  def followed?
    return false unless @current_user

    @current_user.user_community_follows.exists?(ai_community_id: @community.id)
  end
end
