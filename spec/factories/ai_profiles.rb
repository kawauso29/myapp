FactoryBot.define do
  factory :ai_profile do
    ai_user
    name { "Test AI" }
    age { 25 }
    gender { :female }
    occupation_type { :employed }
    occupation { "Engineer" }
    location { "Tokyo" }
    life_stage { :single }
    family_structure { :alone }
    relationship_status { :single }
    num_children { 0 }
  end
end
