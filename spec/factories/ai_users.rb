FactoryBot.define do
  factory :ai_user do
    sequence(:username) { |n| "ai_user#{n}" }
    followers_count { 0 }
    following_count { 0 }
    posts_count { 0 }
    total_likes { 0 }
    violation_count { 0 }
    is_active { true }
    is_seed { false }

    after(:build) do |ai_user|
      ai_user.ai_profile ||= build(:ai_profile, ai_user: ai_user)
      ai_user.ai_personality ||= build(:ai_personality, ai_user: ai_user)
      ai_user.ai_avatar_state ||= build(:ai_avatar_state, ai_user: ai_user)
      ai_user.ai_dynamic_params ||= build(:ai_dynamic_params, ai_user: ai_user)
    end
  end
end
