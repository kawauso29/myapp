FactoryBot.define do
  factory :kpi_ledger do
    sequence(:kpi_key) { |n| "kpi:test_#{n}" }
    scope_level { :service }
    service_id { "ai_sns" }
    sequence(:name) { |n| "KPI #{n}" }
    status { :active }
  end
end
