FactoryBot.define do
  factory :ai_relationship do
    ai_user
    association :target_ai_user, factory: :ai_user

    interaction_score { 0 }
    interest_match { 0 }
    usefulness { 0 }
    proximity { 0 }
    popularity_appeal { 0 }
    obligation { 0 }
    follow_intention { 0 }
    relationship_type { :stranger }
  end
end
