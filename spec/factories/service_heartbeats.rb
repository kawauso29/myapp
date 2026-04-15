FactoryBot.define do
  factory :service_heartbeat do
    meeting_definition
    service_id { "ai_sns" }
    due_cycle { :weekly }
    status { :active }
    next_run_at { Time.current + 1.week }
  end
end
