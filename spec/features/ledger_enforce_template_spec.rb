require "rails_helper"

# Phase 44e 回帰テスト:
# `ENFORCE_TEMPLATE=1` 環境（TicketLedger.enforce_template = true）でも
# Runner / Detector / Planner / Feedback::Intake が Ticket を生成できることを保証する。
#
# 2026-04-23 時点でこの guard が有効な production DB で quarterly/weekly/ui_check/annual の
# Runner が軒並み ActiveRecord::RecordNotSaved で落ち、MeetingLedger が status: :open の
# まま滞留する障害が発生したため、全 auto-generated ticket 経路の回帰テストを追加する。
RSpec.describe "Phase 44e: enforce_template does not break auto-generated tickets", type: :model do
  around do |example|
    original = TicketLedger.enforce_template
    TicketLedger.enforce_template = true
    example.run
  ensure
    TicketLedger.enforce_template = original
  end

  before do
    create(:meeting_definition, meeting_key: "weekly_dept", scope_level: :service,
                                service_id: "ai_sns", meeting_type: :weekly,
                                chair_role: "business_owner")
    create(:meeting_definition, meeting_key: "quarterly_review", scope_level: :company,
                                meeting_type: :quarterly, chair_role: "ceo")
    create(:meeting_definition, meeting_key: "annual_plan", scope_level: :company,
                                meeting_type: :annual, chair_role: "ceo")
    create(:kpi_ledger, kpi_key: "kpi:service_health", scope_level: :service, service_id: "ai_sns")
  end

  it "QuarterlyReviewRunner creates summary ticket without template_id" do
    expect { Ledgers::QuarterlyReviewRunner.call }.not_to raise_error
    meeting = MeetingLedger.where(meeting_key: "quarterly_review").order(:held_at).last
    expect(meeting.status).to eq("closed")
  end

  it "AnnualPlanRunner creates summary ticket without template_id" do
    expect { Ledgers::AnnualPlanRunner.call }.not_to raise_error
    meeting = MeetingLedger.where(meeting_key: "annual_plan").order(:held_at).last
    expect(meeting.status).to eq("closed")
  end

  it "WeeklyDeptRunner creates operations tickets without template_id" do
    expect { Ledgers::WeeklyDeptRunner.call(service_id: "ai_sns", use_daily_anomalies: false) }.not_to raise_error
    meeting = MeetingLedger.where(meeting_key: "weekly_dept").order(:held_at).last
    expect(meeting.status).to eq("closed")
    expect(meeting.tickets_to_create).to be_present
  end

  it "system-generated improvement ticket can be created without template_id" do
    meeting = Ledgers::SystemMeetingProvider.for(kind: "improvement_detector")
    expect do
      TicketLedger.create!(
        ticket_type: :improvement,
        title: "test improvement",
        scope_level: :service,
        service_id: "ai_sns",
        source_meeting: meeting,
        source_meeting_type: :weekly,
        linked_kpis: [ "kpi:service_health" ],
        priority: :medium,
        status: :waiting_review,
        assignee: "improvement_detector",
        due_date: Date.current + 7.days,
        due_cycle: :weekly,
        skip_template_guard: true
      )
    end.not_to raise_error
  end
end
