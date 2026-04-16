FactoryBot.define do
  factory :compliance_rule do
    sequence(:name) { |n| "rule #{n}" }
    law_domain { :pii }
    scope_level { :company }
    severity { :block }
    owner_role { :audit }
    pattern { '[\w.+-]+@[\w-]+\.[\w.-]+' }
    enforced_at { 1.minute.ago }
  end
end
