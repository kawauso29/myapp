require "rails_helper"

RSpec.describe HrEvaluationRunJob, type: :job do
  before { Rails.cache.clear }

  describe "#perform" do
    it "invokes Hr::Evaluator for each top-ranked (owner_dept, service_id)" do
      # job は 過去 90 日 (period_end = 昨日) を見るため、作成日時を昨日に寄せる
      create(:ticket_ledger, owner_dept: "service_lead", service_id: "ai_sns",
             status: :completed, effectiveness_score: 0.7, linked_kpis: [ "kpi:a" ],
             created_at: 3.days.ago)
      create(:ticket_ledger, owner_dept: "service_lead", service_id: "ai_sns",
             status: :completed, effectiveness_score: 0.6, linked_kpis: [ "kpi:a" ],
             created_at: 3.days.ago)

      expect(Hr::Evaluator).to receive(:call).at_least(:once).and_call_original

      described_class.perform_now
    end

    it "swallows errors from individual evaluations" do
      create(:ticket_ledger, owner_dept: "service_lead", service_id: "ai_sns",
             status: :completed, effectiveness_score: 0.7, linked_kpis: [ "kpi:a" ],
             created_at: 3.days.ago)

      allow(Hr::Evaluator).to receive(:call).and_raise(StandardError, "boom")

      expect { described_class.perform_now }.not_to raise_error
    end
  end
end
