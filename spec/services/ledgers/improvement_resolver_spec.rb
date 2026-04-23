require "rails_helper"

RSpec.describe Ledgers::ImprovementResolver do
  describe ".call" do
    let!(:weekly_definition) do
      create(:meeting_definition, meeting_key: "weekly_dept", meeting_type: :weekly, scope_level: :service, service_id: "ai_sns")
    end
    let!(:monthly_definition) do
      create(:meeting_definition, meeting_key: "monthly_ops", meeting_type: :monthly, scope_level: :company, service_id: nil)
    end
    let!(:ui_check_definition) do
      create(:meeting_definition, meeting_key: "ui_check", meeting_type: :weekly, scope_level: :service, service_id: "ai_sns")
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

    it "resolves monthly_hold_accumulation when all escalation tickets in hold_items are resolved" do
      # ImprovementEscalator が monthly_ops.hold_items に書き込む形式（ticket_ledger_id 付き）
      escalation_ticket = create(:ticket_ledger,
                                  ticket_type: :improvement,
                                  status: :approved,  # 解決済み
                                  linked_kpis: { rule: "stale_service" })
      escalation_ticket2 = create(:ticket_ledger,
                                   ticket_type: :improvement,
                                   status: :approved,
                                   linked_kpis: { rule: "stale_service" })
      escalation_ticket3 = create(:ticket_ledger,
                                   ticket_type: :improvement,
                                   status: :cancelled,
                                   linked_kpis: { rule: "stale_service" })

      monthly_meeting = create(:meeting_ledger,
             meeting_definition: monthly_definition,
             meeting_key: "monthly_ops",
             hold_items: [
               { reason: "improvement_escalation_monthly", ticket_ledger_id: escalation_ticket.id },
               { reason: "improvement_escalation_monthly", ticket_ledger_id: escalation_ticket2.id },
               { reason: "improvement_escalation_monthly", ticket_ledger_id: escalation_ticket3.id }
             ],
             status: :closed)

      # monthly_hold_accumulation チケット（3件のhold_itemsが検知された時に生成されたもの）
      accumulation_ticket = create(:ticket_ledger,
                                    ticket_type: :improvement,
                                    status: :waiting_review,
                                    linked_kpis: { rule: "monthly_hold_accumulation", hold_count: 3 })

      # hold_items は 3件だが全て解決済みエスカレーションチケットを参照 → 実質 0件 < 3
      result = described_class.call

      expect(result[:resolved]).to eq(1)
      expect(accumulation_ticket.reload).to be_status_approved
      expect(accumulation_ticket.linked_kpis["resolution"]["hold_count"]).to eq(0)
    end

    it "does not resolve monthly_hold_accumulation when open escalation tickets still exist" do
      open_ticket = create(:ticket_ledger,
                            ticket_type: :improvement,
                            status: :waiting_review,
                            linked_kpis: { rule: "stale_service" })
      open_ticket2 = create(:ticket_ledger,
                             ticket_type: :improvement,
                             status: :overdue,
                             linked_kpis: { rule: "stale_service" })
      open_ticket3 = create(:ticket_ledger,
                             ticket_type: :improvement,
                             status: :waiting_review,
                             linked_kpis: { rule: "stale_service" })

      create(:meeting_ledger,
             meeting_definition: monthly_definition,
             meeting_key: "monthly_ops",
             hold_items: [
               { reason: "improvement_escalation_monthly", ticket_ledger_id: open_ticket.id },
               { reason: "improvement_escalation_monthly", ticket_ledger_id: open_ticket2.id },
               { reason: "improvement_escalation_monthly", ticket_ledger_id: open_ticket3.id }
             ],
             status: :closed)

      accumulation_ticket = create(:ticket_ledger,
                                    ticket_type: :improvement,
                                    status: :waiting_review,
                                    linked_kpis: { rule: "monthly_hold_accumulation", hold_count: 3 })

      result = described_class.call

      expect(result[:resolved]).to eq(0)
      expect(accumulation_ticket.reload).to be_status_waiting_review
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

    it "resolves stale_ui_check when ui_check meeting was recently held" do
      ticket = create(:ticket_ledger,
                      ticket_type: :improvement,
                      status: :waiting_review,
                      service_id: "ai_sns",
                      linked_kpis: { rule: "stale_ui_check", service_id: "ai_sns" })
      create(:meeting_ledger,
             meeting_definition: ui_check_definition,
             meeting_key: "ui_check",
             service_id: "ai_sns",
             held_at: 1.day.ago,
             status: :closed)

      result = described_class.call

      expect(result[:resolved]).to eq(1)
      expect(ticket.reload).to be_status_approved
      expect(ticket.linked_kpis["resolution"]["last_check_at"]).to be_present
    end

    it "does not resolve stale_ui_check when ui_check is still stale" do
      ticket = create(:ticket_ledger,
                      ticket_type: :improvement,
                      status: :waiting_review,
                      service_id: "ai_sns",
                      linked_kpis: { rule: "stale_ui_check", service_id: "ai_sns" })

      result = described_class.call

      expect(result[:resolved]).to eq(0)
      expect(ticket.reload).to be_status_waiting_review
    end
  end
end
