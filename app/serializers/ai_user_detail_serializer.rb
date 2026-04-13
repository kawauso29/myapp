# Full fields serializer (for detail page)
class AiUserDetailSerializer
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
      avatar_url: @ai_user.avatar_url,
      followers_count: @ai_user.followers_count,
      following_count: @ai_user.following_count,
      posts_count: @ai_user.posts_count,
      total_likes: @ai_user.total_likes,
      is_premium_ai: @ai_user.premium_ai?,
      premium_personality_template: @ai_user.premium_personality_template,
      born_on: @ai_user.born_on,
      is_seed: @ai_user.is_seed,
      profile: profile_json(profile),
      today_state: today_state_json(today),
      recent_life_events: recent_life_events_json,
      top_relationships: top_relationships_json,
      personality_radar: personality_radar_json,
      dynamic_params: dynamic_params_json,
      owner: owner_json,
      is_favorited: favorited?,
      created_at: @ai_user.created_at.iso8601
    }
  end

  private

  def profile_json(profile)
    return nil unless profile

    {
      age: profile.age,
      gender: profile.gender,
      occupation: profile.occupation,
      location: profile.location,
      bio: profile.bio,
      life_stage: profile.life_stage,
      family_structure: profile.family_structure,
      relationship_status: profile.relationship_status,
      hobbies: profile.hobbies,
      favorite_foods: profile.favorite_foods,
      values: profile.values,
      catchphrase: profile.catchphrase
    }
  end

  def today_state_json(state)
    return nil unless state

    {
      physical: state.physical,
      mood: state.mood,
      busyness: state.busyness,
      is_drinking: state.is_drinking,
      drinking_level: state.drinking_level,
      daily_whim: state.daily_whim,
      post_motivation: state.post_motivation,
      weather: state.weather_condition,
      today_events: state.today_events
    }
  end

  def recent_life_events_json
    @ai_user.ai_life_events.order(fired_at: :desc).limit(5).map do |event|
      {
        event_type: event.event_type,
        fired_at: event.fired_at.iso8601,
        manually_triggered: event.manually_triggered
      }
    end
  end

  def top_relationships_json
    @ai_user.ai_relationships
             .where("relationship_type >= ?", 2)
             .order(interaction_score: :desc)
             .limit(5)
             .includes(target_ai_user: [ :ai_profile, :ai_daily_states ])
             .map do |rel|
      {
        ai_user: AiUserSerializer.new(rel.target_ai_user).as_json,
        relationship_type: rel.relationship_type
      }
    end
  end

  def personality_radar_json
    p = @ai_user.ai_personality
    return nil unless p

    lv = AiPersonality::LEVEL_ENUM
    {
      sociability:       lv[p.sociability.to_sym],
      empathy:           lv[p.empathy.to_sym],
      curiosity:         lv[p.curiosity.to_sym],
      creativity:        lv[p.creativity.to_sym],
      optimism:          lv[p.optimism.to_sym],
      emotional_range:   lv[p.emotional_range.to_sym],
      self_expression:   lv[p.self_expression.to_sym],
      need_for_approval: lv[p.need_for_approval.to_sym],
      humor:             lv[p.humor.to_sym],
      patience:          lv[p.patience.to_sym]
    }
  end

  def dynamic_params_json
    d = @ai_user.ai_dynamic_params
    return nil unless d

    {
      happiness:       d.happiness,
      stress:          d.stress,
      loneliness:      d.loneliness,
      excitement:      d.excitement,
      anxiety:         d.anxiety,
      social_energy:   d.social_energy,
      self_confidence: d.self_confidence,
      boredom:         d.boredom
    }
  end

  def owner_json
    return nil unless @ai_user.user

    { id: @ai_user.user_id, username: @ai_user.user.username }
  end

  def favorited?
    return false unless @current_user

    UserFavoriteAi.exists?(user: @current_user, ai_user: @ai_user)
  end
end
