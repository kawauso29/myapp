FactoryBot.define do
  factory :audit_decision_ledger do
    association :target_ticket, factory: :ticket_ledger
    decision { :approve }
    reason_code { "approved_no_reservation" }
    audit_role { "audit_board" }
    scope_level { :service }
    service_id { "ai_sns" }
    decided_at { Time.current }
  end

  factory :stop_ledger do
    trigger_type { :kpi_breach }
    trigger_detail { "test trigger" }
    scope_level { :service }
    service_id { "ai_sns" }
    status { :active }
    started_at { Time.current }
    evidence { {} }
  end

  factory :lane_capacity_cap do
    operating_lane { :weekly_improvement }
    wip_cap { 3 }
  end

  factory :knowledge_ledger do
    kind { :adr }
    sequence(:title) { |n| "ADR-#{n}: test" }
    body { "ADR body" }
    status { :accepted }
    accepted_at { Time.current }
    tags { {} }
  end

  factory :hr_evaluation_ledger do
    subject_role { "service_lead" }
    subject_agent { "alice" }
    period_start { Date.current.beginning_of_month }
    period_end { Date.current.end_of_month }
    scope_level { :service }
    service_id { "ai_sns" }
    score { 0.75 }
    status { :draft }
    evidence { {} }
    criteria { {} }
  end

  factory :org_change_ledger do
    change_type { :role_create }
    subject_role { "new_role" }
    scope_level { :service }
    service_id { "ai_sns" }
    status { :proposed }
    diff { {} }
  end

  factory :customer_feedback_ledger do
    source { :in_app }
    scope_level { :service }
    service_id { "ai_sns" }
    raw_text { "sample feedback" }
    status { :new_feedback }
    categorization { {} }
    received_at { Time.current }
  end

  factory :portfolio_strategy_ledger do
    sequence(:strategy_key) { |n| "strategy-#{n}" }
    sequence(:title) { |n| "Strategy #{n}" }
    member_service_ids { [ "ai_sns" ] }
    strategy_type { :kpi_allocation }
    status { :draft }
    targets { {} }
    linked_kpis { [] }
    period_start { Date.current }
  end
end
