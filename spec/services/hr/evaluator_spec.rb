require "rails_helper"

RSpec.describe Hr::Evaluator do
  describe ".call" do
    let(:period_start) { Date.current - 30 }
    let(:period_end)   { Date.current }

    it "creates an HrEvaluationLedger with a scored summary" do
      create(:ticket_ledger,
             ticket_type: "improvement",
             service_id: "ai_sns",
             owner_dept: "service_lead",
             status: :completed,
             effectiveness_score: 0.8,
             linked_kpis: [ "kpi:service_health" ])
      create(:ticket_ledger,
             ticket_type: "operations",
             service_id: "ai_sns",
             owner_dept: "service_lead",
             status: :completed,
             linked_kpis: [ "kpi:placeholder" ])

      result = described_class.call(
        subject_role: "service_lead",
        service_id: "ai_sns",
        scope_level: :service,
        period_start: period_start,
        period_end: period_end
      )

      expect(result.evaluation).to be_persisted
      expect(result.evaluation.subject_role).to eq("service_lead")
      expect(result.evaluation.status).to eq("reviewed")
      expect(result.evaluation.score).to be_present
      expect(result.scores.keys).to match_array(described_class::AXES)
    end

    it "is idempotent for the same period/role/service" do
      create(:ticket_ledger,
             ticket_type: "improvement",
             service_id: "ai_sns",
             owner_dept: "service_lead",
             status: :completed,
             effectiveness_score: 0.8,
             linked_kpis: [ "kpi:service_health" ])

      r1 = described_class.call(subject_role: "service_lead", service_id: "ai_sns",
                                period_start: period_start, period_end: period_end)
      r2 = described_class.call(subject_role: "service_lead", service_id: "ai_sns",
                                period_start: period_start, period_end: period_end)

      expect(r2.evaluation.id).to eq(r1.evaluation.id)
      expect(HrEvaluationLedger.where(subject_role: "service_lead").count).to eq(1)
    end

    it "returns nil axes with no matching tickets" do
      result = described_class.call(subject_role: "unused_role", service_id: "ai_sns",
                                    period_start: period_start, period_end: period_end)

      expect(result.scores[:artifact_quality]).to be_nil
      expect(result.scores[:kpi_contribution]).to be_nil
    end
  end
end
