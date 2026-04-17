FactoryBot.define do
  factory :ticket_ledger do
    ticket_type { "operations" }
    sequence(:title) { |n| "ticket #{n}" }
    scope_level { :service }
    service_id { "ai_sns" }
    source_meeting_type { :weekly }
    # Phase 30c / 補強3: source_meeting_id NOT NULL 化に合わせてデフォルトで会議を紐付ける。
    # テストの意味を壊さないよう、1 テスト内では共有される 1 件の "factory_default_meeting" を使う
    # （大量のテストで合計 meeting 数が意図せず増えるのを防ぐ）。
    source_meeting do
      definition = MeetingDefinition.find_by(meeting_key: "factory_default_meeting") ||
                   FactoryBot.create(
                     :meeting_definition,
                     meeting_key: "factory_default_meeting",
                     meeting_type: :weekly,
                     scope_level: :service,
                     service_id: "ai_sns"
                   )
      MeetingLedger.find_by(meeting_definition_id: definition.id, meeting_key: "factory_default_meeting") ||
        FactoryBot.create(
          :meeting_ledger,
          meeting_definition: definition,
          meeting_key: "factory_default_meeting",
          meeting_type: :weekly,
          scope_level: :service,
          service_id: "ai_sns"
        )
    end
    linked_kpis { [ "kpi:service_health" ] }
    linked_artifacts { [] }
    priority { :medium }
    status { :draft }
    due_cycle { :weekly }
  end
end
