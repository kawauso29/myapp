require "rails_helper"

RSpec.describe Ledgers::ImprovementResolver do
  describe ".call" do
    let!(:weekly_definition) do
      create(:meeting_definition, meeting_key: "weekly_dept", meeting_type: :weekly, scope_level: :service, service_id: "ai_sns")
    end
    let!(:monthly_definition) do
      create(:meeting_definition, meeting_key: "monthly_ops", meeting_type: :monthly, scope_level: :company, service_id: nil)
    end

    it "resolves high_overdue_rate when overdue rate is cleared" do
      ticket = create(:ticket_ledger, ticket_type: :improvement, status: :waiting_review, linked_kpis: { rule: "high_overdue_rate" })
      create_list(:ticket_ledger, 5, status: :approved, created_at: 1.day.ago)

      result = described_class.call

      expect(result[:resolved]).to eq(1)
      expect(ticket.reload).to be_status_approved
      expect(ticket.linked_kpis["resolution"]["current_rate"]).to eq("0.0%")
    end

    it "resolves missing_kpi_definition when kpis are defined" do
      ticket = create(:ticket_ledger,
                      ticket_type: :improvement,
                      status: :waiting_review,
                      linked_kpis: { rule: "missing_kpi_definition", keys: [ "kpi:new" ] })
      create(:kpi_ledger, kpi_key: "kpi:new", scope_level: :service, service_id: "ai_sns")

      result = described_class.call

      expect(result[:resolved]).to eq(1)
      expect(ticket.reload).to be_status_approved
      expect(ticket.linked_kpis["resolution"]["missing_keys"]).to eq([])
    end

    it "resolves stale_service when weekly audit exists within 14 days" do
      ticket = create(:ticket_ledger,
                      ticket_type: :improvement,
                      status: :waiting_review,
                      service_id: "ai_sns",
                      linked_kpis: { rule: "stale_service", service_id: "ai_sns" })
      create(:meeting_ledger,
             meeting_definition: weekly_definition,
             meeting_key: "weekly_dept",
             service_id: "ai_sns",
             held_at: 1.day.ago,
             status: :closed)

      result = described_class.call

      expect(result[:resolved]).to eq(1)
      expect(ticket.reload).to be_status_approved
      expect(ticket.linked_kpis["resolution"]["last_audit_at"]).to be_present
    end

    it "resolves monthly_hold_accumulation when latest monthly hold count is below 3" do
      ticket = create(:ticket_ledger,
                      ticket_type: :improvement,
                      status: :waiting_review,
                      linked_kpis: { rule: "monthly_hold_accumulation", hold_count: 5 })
      create(:meeting_ledger,
             meeting_definition: monthly_definition,
             meeting_key: "monthly_ops",
             hold_items: [ { reason: "x" }, { reason: "y" } ],
             status: :closed)

      result = described_class.call

      expect(result[:resolved]).to eq(1)
      expect(ticket.reload).to be_status_approved
      expect(ticket.linked_kpis["resolution"]["hold_count"]).to eq(2)
    end

    it "does not resolve when condition persists" do
      ticket = create(:ticket_ledger, ticket_type: :improvement, status: :waiting_review, linked_kpis: { rule: "high_overdue_rate" })
      create_list(:ticket_ledger, 3, status: :overdue, created_at: 1.day.ago)
      create_list(:ticket_ledger, 1, status: :approved, created_at: 1.day.ago)

      result = described_class.call

      expect(result[:resolved]).to eq(0)
      expect(ticket.reload).to be_status_waiting_review
      expect(ticket.linked_kpis["resolution"]).to be_nil
    end
  end
end
