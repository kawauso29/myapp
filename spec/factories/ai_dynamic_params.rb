FactoryBot.define do
  factory :ai_dynamic_params, class: "AiDynamicParams" do
    ai_user
    dissatisfaction { 10 }
    loneliness { 10 }
    happiness { 50 }
    fatigue_carried { 0 }
    boredom { 10 }
    relationship_dissatisfaction { 0 }
    relationship_duration_days { 0 }
  end
end
