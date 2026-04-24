require "rails_helper"

RSpec.describe Reinforcements::Planner do
  describe ".call" do
    let!(:kpi) do
      KpiLedger.create!(
        kpi_key: "kpi:ai_sns_wau",
        scope_level: :service,
        service_id: "ai_sns",
        name: "WAU",
        status: :active,
        current_value: { "value" => 50 },
        target_value:  { "value" => 100 }
      )
    end

    it "creates a waiting_review improvement ticket when KPI actual < target * UNDERPERFORM_RATIO" do
      expect { described_class.call }.to change { TicketLedger.ticket_type_improvement.count }.by(1)

      ticket = TicketLedger.ticket_type_improvement.last
      expect(ticket.status).to eq("waiting_review")
      expect(ticket.escalation_to).to eq("monthly")
      expect(ticket.assignee).to eq("reinforcements_planner")
      expect(ticket.improvement_pattern_key).to eq("planner:kpi_underperform:kpi:ai_sns_wau")
      expect(ticket.linked_kpis).to eq([ "kpi:ai_sns_wau" ])
      expect(ticket.service_id).to eq("ai_sns")
      expect(ticket.scope_level).to eq("service")
    end

    it "does not create when actual >= target * UNDERPERFORM_RATIO" do
      kpi.update!(current_value: { "value" => 90 })
      expect { described_class.call }.not_to change { TicketLedger.count }
    end

    it "skips when an open improvement with same pattern_key exists" do
      described_class.call
      expect { described_class.call }.not_to change { TicketLedger.count }
    end

    it "skips when EffectivenessEvaluator marks the pattern as low_effectiveness" do
      fake = Reinforcements::EffectivenessEvaluator::Result.new(
        pattern_key: "planner:kpi_underperform:kpi:ai_sns_wau",
        average_score: 0.1,
        sample_size: 5,
        low_effectiveness: true
      )
      allow(Reinforcements::EffectivenessEvaluator).to receive(:evaluate).and_return(fake)

      result = described_class.call
      expect(result[:created]).to eq(0)
      expect(result[:details][:skipped].first[:reason]).to eq("low_effectiveness_pattern")
    end

    it "caps creation at MAX_PER_RUN" do
      stub_const("Reinforcements::Planner::MAX_PER_RUN", 1)
      KpiLedger.create!(
        kpi_key: "kpi:ai_sns_retention_7d",
        scope_level: :service,
        service_id: "ai_sns",
        name: "ret",
        status: :active,
        current_value: { "value" => 10 },
        target_value:  { "value" => 100 }
      )

      result = described_class.call
      expect(result[:created]).to eq(1)
    end

    it "skips KPIs without target_value" do
      kpi.update!(target_value: {})
      expect { described_class.call }.not_to change { TicketLedger.count }
    end
  end
end
