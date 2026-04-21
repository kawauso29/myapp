require "rails_helper"

RSpec.describe Ledgers::AnnualPlanRunner do
  describe ".call" do
    let!(:definition) do
      create(
        :meeting_definition,
        meeting_key: "annual_plan",
        meeting_type: :annual_plan,
        scope_level: :company,
        service_id: nil,
        chair_role: "ceo"
      )
    end
    let!(:quarterly_definition) do
      create(:meeting_definition, meeting_key: "quarterly_review", meeting_type: :quarterly_review, scope_level: :company, service_id: nil)
    end
    let!(:weekly_definition) { create(:meeting_definition, meeting_key: "weekly_dept", meeting_type: :weekly, scope_level: :service, service_id: "ai_sns") }

    before do
      # スナップショットDBの既存 MeetingLedger がカウントに混入しないよう事前に除去する
      MeetingLedger.delete_all
      TicketLedger.delete_all
      # 圧縮 annual = 7 日が range_start
      quarterly = create(:meeting_ledger, meeting_definition: quarterly_definition, meeting_key: "quarterly_review", meeting_type: :quarterly_review, created_at: 3.days.ago, held_at: 3.days.ago)
      weekly_recent = create(:meeting_ledger, meeting_definition: weekly_definition, meeting_key: "weekly_dept", meeting_type: :weekly, created_at: 1.day.ago, held_at: 1.day.ago)
      # 範囲外（7 日より前）: カウントされない
      create(:meeting_ledger, meeting_definition: weekly_definition, meeting_key: "weekly_dept", meeting_type: :weekly, created_at: 30.days.ago, held_at: 30.days.ago)

      create(:ticket_ledger, ticket_type: "quarterly_review", status: :approved, created_at: 4.days.ago, source_meeting: quarterly)
      create(:ticket_ledger, status: :approved, created_at: 2.days.ago, source_meeting: weekly_recent)
      create(:ticket_ledger, status: :overdue, created_at: 1.day.ago, source_meeting: weekly_recent)
      # 範囲外
      create(:ticket_ledger, status: :cancelled, created_at: 30.days.ago, source_meeting: weekly_recent)
    end

    it "creates annual plan meeting and summary ticket" do
      meeting = described_class.call
      ticket = TicketLedger.where(ticket_type: "annual_plan").order(:id).last

      expect(meeting.meeting_key).to eq("annual_plan")
      expect(meeting).to be_scope_level_company
      expect(meeting).to be_status_closed
      expect(ticket.title).to eq("FY#{Date.current.year} Annual Plan")
      expect(ticket).to be_status_approved
      expect(ticket.assignee).to eq("annual_plan_runner")
      expect(ticket.due_date).to eq(Ledgers::TimeAxis.due_date_for(:annual))
      expect(ticket.resolved_at).to be_present
      expect(ticket.linked_kpis).to include(
        "total_meetings" => 2,
        "quarterly_reviews" => 1,
        "tickets_total" => 3,
        "tickets_approved" => 2,
        "overdue_rate" => "33.3%"
      )
      expect(ticket.linked_artifacts).to include(
        "meetings_by_key" => include("quarterly_review" => 1, "weekly_dept" => 1),
        "tickets_by_status" => include("approved" => 2, "overdue" => 1)
      )
      expect(meeting.tickets_to_create).to include(a_hash_including("ticket_id" => ticket.id))
    end

    it "carries over hold_items from previous quarterly_review meeting (補強8)" do
      prev_quarterly = create(:meeting_ledger, meeting_definition: quarterly_definition, meeting_key: "quarterly_review",
                              meeting_type: :quarterly_review, hold_items: [ { "title" => "quarterly pending" } ])

      meeting = described_class.call

      expect(meeting.carry_over_items).to eq([ { "title" => "quarterly pending" } ])
    end
  end
end
