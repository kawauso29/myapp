FactoryBot.define do
  factory :meeting_definition do
    sequence(:meeting_key) { |n| "meeting_#{n}" }
    meeting_type { :weekly }
    scope_level { :service }
    service_id { "ai_sns" }
    chair_role { "business_owner" }
    participant_roles { %w[planning dev audit cs business_owner] }
    writes_ledgers { %w[meeting_ledger ticket_ledger] }
    active { true }
  end
end
