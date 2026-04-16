require "rails_helper"

RSpec.describe Ledgers::MonthlyOpsRunner do
  describe ".call" do
    let!(:monthly_definition) do
      create(:meeting_definition,
             meeting_key: "monthly_ops",
             meeting_type: :monthly,
             scope_level: :company,
             service_id: nil,
             participant_roles: %w[executive_planning executive_development executive_audit executive_hr business_owner])
    end

    let!(:waiting_ticket) do
      create(:ticket_ledger,
             status: :waiting_review,
             escalation_to: :monthly,
             due_cycle: :monthly)
    end

    it "resolves waiting_review ticket by monthly decision" do
      meeting = described_class.call(resolution_map: { waiting_ticket.id => "cancelled" })

      expect(waiting_ticket.reload).to be_status_cancelled
      expect(waiting_ticket.resolved_at).to be_present
      expect(waiting_ticket.assignee).to eq("monthly_ops_runner")
      expect(waiting_ticket.due_date).to eq(Date.current + 30.days)
      expect(waiting_ticket.escalation_to).to be_nil
      expect(meeting.decisions).to include(a_hash_including("ticket_id" => waiting_ticket.id, "resolution" => "cancelled"))
    end
  end
end
