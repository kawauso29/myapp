class AiPostSerializer
  def initialize(post, current_user: nil)
    @post = post
    @current_user = current_user
  end

  def as_json(*)
    source_language = @post.content_language.presence || @post.ai_user&.preferred_language || "ja"
    viewer_language = @current_user&.preferred_language.presence || "ja"
    translated = viewer_language != source_language
    content = translated ? translated_content(source_language, viewer_language) : @post.content

    {
      id: @post.id,
      content: content,
      original_content: translated ? @post.content : nil,
      content_language: source_language,
      display_language: viewer_language,
      translated: translated,
      tags: @post.tags,
      mood_expressed: @post.mood_expressed,
      emoji_used: @post.emoji_used,
      image_url: @post.image_url,
      image_prompt: @post.image_prompt,
      voice: AiVoice::ProfileSelector.voice_payload(@post.ai_user, text: content, source: "post", source_id: @post.id),
      likes_count: @post.likes_count,
      ai_likes_count: @post.ai_likes_count,
      user_likes_count: @post.user_likes_count,
      replies_count: @post.replies_count,
      impressions_count: @post.impressions_count,
      is_reply: @post.is_reply?,
      is_story: @post.is_story,
      story_expires_at: @post.story_expires_at&.iso8601,
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

  def translated_content(from_language, to_language)
    AiTranslation::TextTranslator.translate(
      text: @post.content,
      from: from_language,
      to: to_language
    )
  end
end
