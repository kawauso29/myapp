FactoryBot.define do
  factory :meeting_ledger do
    meeting_definition
    meeting_key { meeting_definition.meeting_key }
    meeting_type { meeting_definition.meeting_type }
    scope_level { meeting_definition.scope_level }
    service_id { meeting_definition.service_id }
    chair { meeting_definition.chair_role }
    participants { meeting_definition.participant_roles }
    held_at { Time.current }
    status { :open }
  end
end
