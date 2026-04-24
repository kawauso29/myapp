require "rails_helper"

RSpec.describe Ledgers::QuarterlyReviewRunner do
  describe ".call" do
    let!(:definition) do
      create(
        :meeting_definition,
        meeting_key: "quarterly_review",
        meeting_type: :quarterly_review,
        scope_level: :company,
        service_id: nil,
        chair_role: "cto"
      )
    end
    let!(:weekly_definition) { create(:meeting_definition, meeting_key: "weekly_dept", meeting_type: :weekly, scope_level: :service, service_id: "ai_sns") }
    let!(:monthly_definition) { create(:meeting_definition, meeting_key: "monthly_ops", meeting_type: :monthly, scope_level: :company, service_id: nil) }

    before do
      allow(Ledgers::ImprovementEscalator).to receive(:call).and_return(
        operation: "escalate_improvements",
        overdue_marked: 0,
        escalated_monthly: 0,
        escalated_quarterly: 0,
        details: []
      )
      # 圧縮 quarterly = 2 日が range_start。範囲内 / 範囲外の境界をテストする
      create(:meeting_ledger, meeting_definition: weekly_definition, meeting_key: "weekly_dept", meeting_type: :weekly, created_at: 6.hours.ago, held_at: 6.hours.ago)
      create(:meeting_ledger, meeting_definition: monthly_definition, meeting_key: "monthly_ops", meeting_type: :monthly, created_at: 1.day.ago, held_at: 1.day.ago)
      # 範囲外（2 日より前）: カウントされない
      create(:meeting_ledger, meeting_definition: weekly_definition, meeting_key: "weekly_dept", meeting_type: :weekly, created_at: 5.days.ago, held_at: 5.days.ago)

      create(:ticket_ledger, status: :approved, created_at: 6.hours.ago)
      create(:ticket_ledger, status: :cancelled, created_at: 12.hours.ago)
      create(:ticket_ledger, status: :overdue, created_at: 1.day.ago)
      # 範囲外: カウントされない
      create(:ticket_ledger, status: :approved, created_at: 5.days.ago)

      create(:kpi_snapshot, recorded_on: 1.day.ago.to_date)
      # 範囲外
      create(:kpi_snapshot, recorded_on: 5.days.ago.to_date)
    end

    it "creates quarterly review meeting and summary ticket" do
      meeting = described_class.call
      ticket = TicketLedger.where(ticket_type: "quarterly_review").order(:id).last

      expect(meeting.meeting_key).to eq("quarterly_review")
      expect(meeting).to be_scope_level_company
      expect(meeting).to be_status_closed
      expect(ticket.title).to match(/^Q\d #{Date.current.year} Review Summary$/)
      expect(ticket).to be_status_approved
      expect(ticket.assignee).to eq("quarterly_review_runner")
      expect(ticket.due_date).to eq(Ledgers::TimeAxis.due_date_for(:quarterly))
      expect(ticket.resolved_at).to be_present
      expect(ticket.linked_kpis).to include(
        "meetings_held" => 2,
        "tickets_total" => 3,
        "tickets_approved" => 1,
        "tickets_cancelled" => 1,
        "tickets_overdue" => 1
      )
      expect(ticket.linked_artifacts.size).to eq(1)
      expect(meeting.tickets_to_create).to include(a_hash_including("ticket_id" => ticket.id))
      expect(Ledgers::ImprovementEscalator).to have_received(:call)
    end

    it "carries over hold_items from previous monthly_ops meeting (補強8)" do
      monthly = create(:meeting_ledger, meeting_definition: monthly_definition, meeting_key: "monthly_ops",
                       meeting_type: :monthly, hold_items: [ { "title" => "monthly pending" } ])

      meeting = described_class.call

      expect(meeting.carry_over_items).to eq([ { "title" => "monthly pending" } ])
    end
    context "リトライ耐性（idempotency_key 重複）" do
      it "既に closed な会議が同一スロットにあれば即返し（エラーなし）" do
        quarter = ((Date.current.month - 1) / 3) + 1
        ikey = Ledgers::IdempotencyKey.for_meeting(
          prefix: "quarterly_review",
          parts: [ Date.current.year, "q#{quarter}" ],
          cadence: :quarterly
        )
        existing = create(:meeting_ledger,
                          meeting_definition: definition,
                          meeting_key: "quarterly_review",
                          meeting_type: :quarterly_review,
                          status: :closed,
                          idempotency_key: ikey)

        result = described_class.call

        expect(result.id).to eq(existing.id)
        expect(Ledgers::ImprovementEscalator).not_to have_received(:call)
      end

      it "open な会議が同一スロットにあれば再利用してエラーにならない" do
        quarter = ((Date.current.month - 1) / 3) + 1
        ikey = Ledgers::IdempotencyKey.for_meeting(
          prefix: "quarterly_review",
          parts: [ Date.current.year, "q#{quarter}" ],
          cadence: :quarterly
        )
        open_meeting = create(:meeting_ledger,
                              meeting_definition: definition,
                              meeting_key: "quarterly_review",
                              meeting_type: :quarterly_review,
                              status: :open,
                              idempotency_key: ikey)

        expect { described_class.call }.not_to raise_error
        expect(MeetingLedger.where(meeting_key: "quarterly_review").count).to eq(1)
      end
    end
  end
end
