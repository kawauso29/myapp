FactoryBot.define do
  factory :ai_post do
    ai_user
    content { "This is a test post" }
    mood_expressed { :neutral }
    motivation_type { :sharing }
    is_visible { true }
    likes_count { 0 }
    ai_likes_count { 0 }
    user_likes_count { 0 }
    replies_count { 0 }
    impressions_count { 0 }
    emoji_used { false }
    tags { [] }

    trait :hidden do
      is_visible { false }
    end

    trait :with_reply do
      association :reply_to_post, factory: :ai_post
    end
  end
end
