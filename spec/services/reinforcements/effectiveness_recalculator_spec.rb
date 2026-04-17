require "rails_helper"

RSpec.describe Reinforcements::EffectivenessRecalculator do
  describe ".call" do
    let!(:kpi) do
      KpiLedger.create!(
        kpi_key: "kpi:ai_sns_wau",
        scope_level: :service,
        service_id: "ai_sns",
        name: "WAU",
        status: :active,
        current_value: { "value" => 80 },
        target_value: { "value" => 100 }
      )
    end

    it "writes effectiveness_score to completed improvement tickets with linked KPIs" do
      ticket = create(:ticket_ledger,
                      ticket_type: :improvement,
                      status: :completed,
                      linked_kpis: [ "kpi:ai_sns_wau" ])
      ticket.update_columns(effectiveness_score: nil)

      result = described_class.call

      expect(result[:updated]).to eq(1)
      ticket.reload
      expect(ticket.effectiveness_score.to_f).to be_within(0.001).of(0.8)
      expect(ticket.effectiveness_sample_size).to eq(1)
      expect(ticket.effectiveness_updated_at).to be_present
    end

    it "clamps ratio above 1.0 to 1.0" do
      kpi.update!(current_value: { "value" => 150 }, target_value: { "value" => 100 })
      ticket = create(:ticket_ledger, ticket_type: :improvement, status: :completed, linked_kpis: [ "kpi:ai_sns_wau" ])
      ticket.update_columns(effectiveness_score: nil)

      described_class.call
      expect(ticket.reload.effectiveness_score.to_f).to eq(1.0)
    end

    it "skips tickets with no kpi: prefixed strings in linked_kpis" do
      ticket = create(:ticket_ledger,
                      ticket_type: :improvement,
                      status: :completed,
                      linked_kpis: { "rule" => "stale_service", "service_id" => "ai_sns" })
      ticket.update_columns(effectiveness_score: nil)

      result = described_class.call
      expect(result[:skipped_no_kpi]).to eq(1)
      expect(ticket.reload.effectiveness_score).to be_nil
    end

    it "skips tickets when target_value is missing" do
      kpi.update!(target_value: {})
      ticket = create(:ticket_ledger, ticket_type: :improvement, status: :completed, linked_kpis: [ "kpi:ai_sns_wau" ])
      ticket.update_columns(effectiveness_score: nil)

      result = described_class.call
      expect(result[:skipped_no_target]).to eq(1)
      expect(ticket.reload.effectiveness_score).to be_nil
    end

    it "does not re-process tickets that already have effectiveness_score" do
      ticket = create(:ticket_ledger, ticket_type: :improvement, status: :completed, linked_kpis: [ "kpi:ai_sns_wau" ], effectiveness_score: 0.5)

      described_class.call
      expect(ticket.reload.effectiveness_score.to_f).to eq(0.5)
    end
  end
end
