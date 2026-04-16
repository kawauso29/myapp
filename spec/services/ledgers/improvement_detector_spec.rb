require "rails_helper"

RSpec.describe Ledgers::ImprovementDetector do
  describe ".call" do
    it "creates ticket when overdue rate is above 20%" do
      create_list(:ticket_ledger, 3, status: :overdue, created_at: 2.days.ago)
      create_list(:ticket_ledger, 7, status: :approved, created_at: 2.days.ago)

      result = described_class.call

      expect(result[:created_tickets_count]).to eq(1)
      ticket = TicketLedger.ticket_type_improvement.last
      expect(ticket.title).to match(/^High overdue rate detected/)
      expect(ticket.linked_kpis).to include("rule" => "overdue_rate", "threshold" => "20%")
      expect(ticket.assignee).to eq("improvement_detector")
      expect(ticket).to be_status_waiting_review
      expect(ticket.due_date).to eq(Date.current + 14.days)
    end

    it "creates ticket when KPI definitions are missing in recent weekly holds" do
      weekly_definition = create(:meeting_definition, meeting_key: "weekly_dept", meeting_type: :weekly, scope_level: :service, service_id: "ai_sns")
      create(
        :meeting_ledger,
        meeting_definition: weekly_definition,
        meeting_key: "weekly_dept",
        meeting_type: :weekly,
        scope_level: :service,
        service_id: "ai_sns",
        hold_items: [ { reason: "missing_kpi_definition", missing_kpi_keys: [ "kpi:foo", "kpi:bar" ] } ],
        created_at: 1.day.ago
      )

      result = described_class.call

      expect(result[:created_tickets_count]).to eq(1)
      expect(TicketLedger.ticket_type_improvement.last.title).to eq("KPI definitions missing for: kpi:bar, kpi:foo")
    end

    it "creates ticket when latest monthly meeting has more than 3 hold items" do
      monthly_definition = create(:meeting_definition, meeting_key: "monthly_ops", meeting_type: :monthly, scope_level: :company, service_id: nil)
      create(
        :meeting_ledger,
        meeting_definition: monthly_definition,
        meeting_key: "monthly_ops",
        meeting_type: :monthly,
        scope_level: :company,
        hold_items: [ { reason: "a" }, { reason: "b" }, { reason: "c" }, { reason: "d" } ],
        held_at: Time.current
      )

      result = described_class.call

      expect(result[:created_tickets_count]).to eq(1)
      expect(TicketLedger.ticket_type_improvement.last.title).to eq("Monthly ops has 4 unresolved holds")
    end

    it "creates ticket when stale waiting_review tickets exist" do
      create(:ticket_ledger, status: :waiting_review, created_at: 15.days.ago, due_date: Date.current + 1.day)

      result = described_class.call

      expect(result[:created_tickets_count]).to eq(1)
      expect(TicketLedger.ticket_type_improvement.last.title).to eq("1 tickets stale for 14+ days")
    end

    it "does not create duplicate ticket for the same rule" do
      create(
        :ticket_ledger,
        ticket_type: :improvement,
        status: :waiting_review,
        title: "High overdue rate detected (25.0%)",
        linked_kpis: { rule: "overdue_rate", value: "25.0%", threshold: "20%" }
      )
      create_list(:ticket_ledger, 3, status: :overdue, created_at: 2.days.ago)
      create_list(:ticket_ledger, 7, status: :approved, created_at: 2.days.ago)

      result = described_class.call

      expect(result[:created_tickets_count]).to eq(0)
      expect(TicketLedger.ticket_type_improvement.count).to eq(1)
    end

    it "returns result hash with details" do
      create_list(:ticket_ledger, 3, status: :overdue, created_at: 2.days.ago)
      create_list(:ticket_ledger, 7, status: :approved, created_at: 2.days.ago)

      result = described_class.call

      expect(result).to include(:operation, :created_tickets_count, :created_tickets)
      expect(result[:operation]).to eq("detect_improvements")
      expect(result[:created_tickets].first).to include(:id, :title, :rule)
    end
  end
end
