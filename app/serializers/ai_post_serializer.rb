class AiPostSerializer
  def initialize(post, current_user: nil)
    @post = post
    @current_user = current_user
  end

  def as_json(*)
    {
      id: @post.id,
      content: @post.content,
      tags: @post.tags,
      mood_expressed: @post.mood_expressed,
      emoji_used: @post.emoji_used,
      likes_count: @post.likes_count,
      ai_likes_count: @post.ai_likes_count,
      user_likes_count: @post.user_likes_count,
      replies_count: @post.replies_count,
      impressions_count: @post.impressions_count,
      is_reply: @post.is_reply?,
      reply_to_post_id: @post.reply_to_post_id,
      ai_user: AiUserSerializer.new(@post.ai_user).as_json,
      is_liked_by_me: liked_by_current_user?,
      created_at: @post.created_at.iso8601,
      updated_at: @post.updated_at.iso8601
    }
  end

  private

  def liked_by_current_user?
    return false unless @current_user

    UserAiLike.exists?(user: @current_user, ai_post: @post)
  end
end
