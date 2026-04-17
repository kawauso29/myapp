FactoryBot.define do
  factory :experiment_ledger do
    service_id { "ai_sns" }
    scope_level { :service }
    hypothesis { "投稿頻度を2倍にすると engagement が 30% 向上する" }
    kpi_targets { [{ "kpi_key" => "kpi:engagement", "threshold" => 0.3 }] }
    deadline { 90.days.from_now.to_date }
    status { :active }
    created_by { "service_planning" }
    linked_kpis { ["kpi:engagement"] }
  end
end
