FactoryBot.define do
  factory :ticket_ledger do
    ticket_type { "operations" }
    sequence(:title) { |n| "ticket #{n}" }
    scope_level { :service }
    service_id { "ai_sns" }
    source_meeting_type { :weekly }
    linked_kpis { [ "kpi:service_health" ] }
    linked_artifacts { [] }
    priority { :medium }
    status { :draft }
    due_cycle { :weekly }
  end
end
