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

    before do
      allow(Ledgers::ImprovementResolver).to receive(:call).and_return({ resolved: 0, details: [] })
      allow(Ledgers::ImprovementEscalator).to receive(:call).and_return(
        operation: "escalate_improvements",
        overdue_marked: 0,
        escalated_monthly: 0,
        escalated_quarterly: 0,
        details: []
      )
    end

    it "resolves waiting_review ticket by monthly decision" do
      meeting = described_class.call(resolution_map: { waiting_ticket.id => "cancelled" })

      expect(waiting_ticket.reload).to be_status_cancelled
      expect(waiting_ticket.resolved_at).to be_present
      expect(waiting_ticket.assignee).to eq("monthly_ops_runner")
      expect(waiting_ticket.due_date).to eq(Ledgers::TimeAxis.due_date_for(:monthly))
      expect(waiting_ticket.escalation_to).to be_nil
      expect(meeting.decisions).to include(a_hash_including("ticket_id" => waiting_ticket.id, "resolution" => "cancelled"))
    end

    it "calls improvement resolver after monthly flow" do
      described_class.call(resolution_map: {})

      expect(Ledgers::ImprovementResolver).to have_received(:call)
      expect(Ledgers::ImprovementEscalator).to have_received(:call)
    end
  end
end
