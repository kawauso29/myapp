require "rails_helper"

RSpec.describe Ledgers::WeeklyDeptRunner do
  describe ".call" do
    let!(:weekly_definition) do
      create(:meeting_definition,
             meeting_key: "weekly_dept",
             meeting_type: :weekly,
             scope_level: :service,
             service_id: "ai_sns")
    end

    it "sets waiting_review + escalation_to monthly when weekly audit is NG" do
      create(:kpi_ledger, kpi_key: "kpi:risk", scope_level: :service, service_id: "ai_sns")

      meeting = described_class.call(
        service_id: "ai_sns",
        ticket_inputs: [
          {
            ticket_type: "audit",
            title: "needs review",
            linked_kpis: [ "kpi:risk" ],
            audit_ok: false
          }
        ]
      )

      ticket = TicketLedger.last
      expect(ticket).to be_status_waiting_review
      expect(ticket).to be_escalation_to_monthly
      expect(ticket.linked_kpis).to eq([ "kpi:risk" ])
      expect(ticket.assignee).to eq("ai_sns")
      expect(ticket.due_date).to eq(Date.current + 7.days)
      expect(ticket.resolved_at).to be_nil
      expect(ticket.source_meeting).to eq(meeting)
      expect(meeting.escalations.size).to eq(1)
    end

    it "auto-resolves approved ticket with resolved_at when weekly audit is OK" do
      create(:kpi_ledger, kpi_key: "kpi:service_health", scope_level: :service, service_id: "ai_sns")

      described_class.call(
        service_id: "ai_sns",
        ticket_inputs: [
          {
            ticket_type: "ops",
            title: "approved by weekly audit",
            linked_kpis: [ "kpi:service_health" ],
            audit_ok: true
          }
        ]
      )

      ticket = TicketLedger.last
      expect(ticket).to be_status_approved
      expect(ticket.resolved_at).to be_present
      expect(ticket.assignee).to eq("ai_sns")
      expect(ticket.due_date).to eq(Date.current + 7.days)
    end

    it "holds ticket creation when linked_kpis is empty" do
      expect do
        described_class.call(
          service_id: "ai_sns",
          ticket_inputs: [
            {
              ticket_type: "ops",
              title: "missing kpi",
              linked_kpis: []
            }
          ]
        )
      end.not_to change(TicketLedger, :count)

      meeting = MeetingLedger.last
      expect(meeting.hold_items).to include(a_hash_including("reason" => "missing_linked_kpis"))
    end

    it "holds ticket creation when linked_kpis include unknown keys" do
      create(:kpi_ledger, kpi_key: "kpi:known", scope_level: :service, service_id: "ai_sns")

      expect do
        described_class.call(
          service_id: "ai_sns",
          ticket_inputs: [
            {
              ticket_type: "ops",
              title: "unknown kpi",
              linked_kpis: [ "kpi:known", "kpi:unknown" ]
            }
          ]
        )
      end.not_to change(TicketLedger, :count)

      meeting = MeetingLedger.last
      expect(meeting.hold_items).to include(
        a_hash_including("reason" => "missing_kpi_definition", "missing_kpi_keys" => [ "kpi:unknown" ])
      )
    end
  end
end
