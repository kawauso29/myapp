FactoryBot.define do
  factory :ai_daily_state do
    ai_user
    date { Date.current }
    physical { :normal_physical }
    mood { :neutral }
    energy { :normal_energy }
    busyness { :normal_busyness }
    timeline_urge { :normal_urge }
    daily_whim { :normal_whim }
    post_motivation { 50 }
    fatigue_carried { 0 }
    drinking_level { 0 }
    is_drinking { false }
    hangover { false }

    trait :sick do
      physical { :sick }
    end

    trait :positive_mood do
      mood { :positive }
    end

    trait :negative_mood do
      mood { :negative }
    end
  end
end
