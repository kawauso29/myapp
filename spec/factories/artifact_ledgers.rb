FactoryBot.define do
  factory :artifact_ledger do
    artifact_type { :spec }
    scope_level { :service }
    service_id { "ai_sns" }
    sequence(:title) { |n| "Artifact #{n}" }
    artifact_version { 1 }
    content { { "summary" => "test" } }
    status { :published }
    published_at { Time.current }
  end
end
