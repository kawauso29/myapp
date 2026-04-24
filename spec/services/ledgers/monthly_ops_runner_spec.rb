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

    it "carries over hold_items from previous weekly_dept meeting (補強8)" do
      weekly_def = create(:meeting_definition, meeting_key: "weekly_dept", meeting_type: :weekly, scope_level: :service, service_id: "ai_sns")
      prev_weekly = create(:meeting_ledger, meeting_definition: weekly_def, meeting_key: "weekly_dept",
                           meeting_type: :weekly, hold_items: [ { "title" => "pending item" } ])

      meeting = described_class.call(resolution_map: {})

      expect(meeting.carry_over_items).to eq([ { "title" => "pending item" } ])
    end

    context "リトライ耐性（idempotency_key 重複）" do
      it "既に closed な会議が同一スロットにあれば即返し（エラーなし）" do
        ikey = Ledgers::IdempotencyKey.for_meeting(prefix: "monthly_ops", cadence: :monthly)
        existing = create(:meeting_ledger,
                          meeting_definition: monthly_definition,
                          meeting_key: "monthly_ops",
                          meeting_type: :monthly,
                          status: :closed,
                          idempotency_key: ikey)

        result = described_class.call(resolution_map: {})

        expect(result.id).to eq(existing.id)
        expect(Ledgers::ImprovementResolver).not_to have_received(:call)
      end

      it "open な会議が同一スロットにあれば再利用してエラーにならない" do
        ikey = Ledgers::IdempotencyKey.for_meeting(prefix: "monthly_ops", cadence: :monthly)
        create(:meeting_ledger,
               meeting_definition: monthly_definition,
               meeting_key: "monthly_ops",
               meeting_type: :monthly,
               status: :open,
               idempotency_key: ikey)

        expect { described_class.call(resolution_map: {}) }.not_to raise_error
        expect(MeetingLedger.where(meeting_key: "monthly_ops").count).to eq(1)
      end
    end
  end
end
