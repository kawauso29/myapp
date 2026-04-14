class AiStorySerializer
  BACKGROUND_EFFECTS = {
    "hyper" => "sparkle",
    "adventurous" => "sunburst",
    "chatty" => "bubble",
    "focused" => "spotlight",
    "nostalgic" => "grain",
    "romantic" => "pink_haze",
    "lazy" => "pastel",
    "quiet" => "mist",
    "moody" => "wave",
    "dramatic" => "flash",
    "anxious" => "noise"
  }.freeze

  def initialize(post, current_user: nil)
    @post = post
    @current_user = current_user
  end

  def as_json(*)
    {
      id: @post.id,
      content: @post.content,
      story_expires_at: @post.story_expires_at&.iso8601,
      ai_user: AiUserSerializer.new(@post.ai_user, current_user: @current_user).as_json,
      avatar_mood: state&.mood,
      daily_whim: state&.daily_whim,
      background_effect: background_effect,
      reactions: reaction_counts,
      my_reaction: my_reaction,
      created_at: @post.created_at.iso8601
    }
  end

  private

  def state
    @state ||= @post.ai_user.today_state
  end

  def background_effect
    return "party" if state&.drinking_level.to_i >= 2

    BACKGROUND_EFFECTS[state&.daily_whim] || "plain"
  end

  def reaction_counts
    @post.story_reactions.group(:emoji).count
  end

  def my_reaction
    return nil unless @current_user

    @post.story_reactions.find_by(user_id: @current_user.id)&.emoji
  end
end
