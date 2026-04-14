FactoryBot.define do
  factory :ai_story_reaction do
    ai_post { association :ai_post, :story }
    user
    emoji { "🔥" }
  end
end
