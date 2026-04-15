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
      expect(ticket.source_meeting).to eq(meeting)
      expect(meeting.escalations.size).to eq(1)
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
  end
end
