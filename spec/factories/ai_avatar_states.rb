FactoryBot.define do
  factory :ai_avatar_state do
    ai_user
    hair_length { :medium }
    expression { :normal }
    body_type { :normal_body }
  end
end
