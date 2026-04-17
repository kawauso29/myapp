FactoryBot.define do
  factory :service_ledger do
    sequence(:service_id) { |n| "service_#{n}" }
    scope_level { :service }
    business_owner { "owner" }
    status { :active }
  end
end
