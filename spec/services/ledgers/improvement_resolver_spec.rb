require "rails_helper"

RSpec.describe Ledgers::ImprovementResolver do
  describe ".call" do
    it "resolves overdue rate ticket when overdue rate is <= 20%" do
      create_list(:ticket_ledger, 1, status: :overdue, created_at: 2.days.ago)
      create_list(:ticket_ledger, 9, status: :approved, created_at: 2.days.ago)
      ticket = create(
        :ticket_ledger,
        ticket_type: :improvement,
        status: :waiting_review,
        linked_kpis: { rule: "overdue_rate", value: "40%", threshold: "20%" }
      )

      result = described_class.call

      expect(result[:resolved_tickets_count]).to eq(1)
      expect(ticket.reload).to be_status_approved
      expect(ticket.resolved_at).to be_present
    end

    it "resolves missing KPI ticket when KPI definitions are added" do
      create(:kpi_ledger, kpi_key: "kpi:foo", scope_level: :service, service_id: "ai_sns")
      create(:kpi_ledger, kpi_key: "kpi:bar", scope_level: :service, service_id: "ai_sns")
      ticket = create(
        :ticket_ledger,
        ticket_type: :improvement,
        status: :waiting_review,
        linked_kpis: { rule: "missing_kpi_definition", keys: [ "kpi:foo", "kpi:bar" ] }
      )

      result = described_class.call

      expect(result[:resolved_tickets_count]).to eq(1)
      expect(ticket.reload).to be_status_approved
    end

    it "does not resolve ticket when issue still exists" do
      create_list(:ticket_ledger, 3, status: :overdue, created_at: 2.days.ago)
      create_list(:ticket_ledger, 7, status: :approved, created_at: 2.days.ago)
      ticket = create(
        :ticket_ledger,
        ticket_type: :improvement,
        status: :waiting_review,
        linked_kpis: { rule: "overdue_rate", value: "30%", threshold: "20%" }
      )

      result = described_class.call

      expect(result[:resolved_tickets_count]).to eq(0)
      expect(ticket.reload).to be_status_waiting_review
    end
  end
end
