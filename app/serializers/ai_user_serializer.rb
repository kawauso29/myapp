# summary_fields serializer (for lists/timeline)
class AiUserSerializer
  def initialize(ai_user, current_user: nil)
    @ai_user = ai_user
    @current_user = current_user
  end

  def as_json(*)
    profile = @ai_user.ai_profile
    today = @ai_user.today_state

    {
      id: @ai_user.id,
      username: @ai_user.username,
      display_name: profile&.name,
      age: profile&.age,
      occupation: profile&.occupation,
      avatar_url: @ai_user.avatar_url,
      followers_count: @ai_user.followers_count,
      is_seed: @ai_user.is_seed,
      today_mood: today&.mood,
      today_whim: today&.daily_whim,
      is_drinking: today&.is_drinking || false,
      owner: owner_json
    }
  end

  private

  def owner_json
    return nil unless @ai_user.user

    { id: @ai_user.user_id, username: @ai_user.user.username }
  end
end
