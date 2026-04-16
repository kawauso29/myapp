require "rails_helper"
require "rake"
require "json"
require "stringio"

RSpec.describe "ledgers rake tasks" do
  before(:all) do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
  end

  describe "ledgers:run_weekly_dept" do
    let(:task) { Rake::Task["ledgers:run_weekly_dept"] }
    let(:meeting) do
      instance_double(
        MeetingLedger,
        id: 1,
        meeting_key: "weekly_dept",
        service_id: "ai_sns",
        created_at: Time.current,
        tickets_to_create: [ { ticket_id: 10 }, { ticket_id: 11 } ],
        hold_items: [
          { reason: "missing_linked_kpis" },
          { reason: "missing_kpi_definition", missing_kpi_keys: [ "kpi:risk", "kpi:risk" ] }
        ]
      )
    end

    before do
      task.reenable
      allow(Ledgers::WeeklyDeptRunner).to receive(:call).and_return(meeting)
    end

    it "runs without raising" do
      output = capture_stdout { task.invoke("ai_sns") }
      payload = JSON.parse(output)

      expect(payload.dig("meeting_ledger", "id")).to eq(1)
      expect(payload.dig("meeting_ledger", "meeting_key")).to eq("weekly_dept")
      expect(payload.dig("counts", "tickets_created")).to eq(2)
      expect(payload.dig("counts", "held_items")).to eq(2)
      expect(payload.dig("tickets", "info")).to eq([])
      expect(payload.dig("holds", "grouped_by_reason")).to eq(
        "missing_kpi_definition" => 1,
        "missing_linked_kpis" => 1
      )
      expect(payload.dig("holds", "missing_kpi_definition_keys")).to eq([ "kpi:risk" ])
      expect(payload.dig("improvements", "detected")).to eq(0)
      expect(payload.dig("improvements", "resolved")).to eq(0)
      expect(Ledgers::WeeklyDeptRunner).to have_received(:call).with(service_id: "ai_sns")
    end
  end

  describe "ledgers:run_monthly_ops" do
    let(:task) { Rake::Task["ledgers:run_monthly_ops"] }
    let(:meeting) do
      instance_double(
        MeetingLedger,
        id: 2,
        meeting_key: "monthly_ops",
        service_id: nil,
        created_at: Time.current,
        tickets_to_create: [],
        hold_items: []
      )
    end

    before do
      task.reenable
      allow(Ledgers::MonthlyOpsRunner).to receive(:call).and_return(meeting)
    end

    it "runs without raising" do
      output = capture_stdout { task.invoke }
      payload = JSON.parse(output)

      expect(payload["operation"]).to eq("monthly_ops")
      expect(payload.dig("meeting_ledger", "meeting_key")).to eq("monthly_ops")
      expect(payload.dig("counts", "tickets_created")).to eq(0)
      expect(payload.dig("counts", "held_items")).to eq(0)
      expect(payload.dig("tickets", "info")).to eq([])
      expect(payload.dig("improvements", "detected")).to eq(0)
      expect(payload.dig("improvements", "resolved")).to eq(0)
      expect(Ledgers::MonthlyOpsRunner).to have_received(:call)
    end
  end

  describe "ledgers:check_overdue" do
    let(:task) { Rake::Task["ledgers:check_overdue"] }

    before do
      task.reenable
      allow(TicketOverdueCheckJob).to receive(:perform_now).and_return(3)
    end

    it "runs overdue check job inline" do
      output = capture_stdout { task.invoke }
      payload = JSON.parse(output)

      expect(payload).to eq(
        "operation" => "check_overdue",
        "overdue_marked" => 3
      )
      expect(TicketOverdueCheckJob).to have_received(:perform_now)
    end
  end

  describe "ledgers:run_quarterly_review" do
    let(:task) { Rake::Task["ledgers:run_quarterly_review"] }
    let(:meeting) do
      instance_double(
        MeetingLedger,
        id: 3,
        meeting_key: "quarterly_review",
        service_id: nil,
        created_at: Time.current,
        tickets_to_create: [],
        hold_items: []
      )
    end

    before do
      task.reenable
      allow(Ledgers::QuarterlyReviewRunner).to receive(:call).and_return(meeting)
    end

    it "runs without raising" do
      output = capture_stdout { task.invoke }
      payload = JSON.parse(output)

      expect(payload["operation"]).to eq("quarterly_review")
      expect(payload.dig("meeting_ledger", "meeting_key")).to eq("quarterly_review")
      expect(Ledgers::QuarterlyReviewRunner).to have_received(:call)
    end
  end

  describe "ledgers:run_annual_plan" do
    let(:task) { Rake::Task["ledgers:run_annual_plan"] }
    let(:meeting) do
      instance_double(
        MeetingLedger,
        id: 4,
        meeting_key: "annual_plan",
        service_id: nil,
        created_at: Time.current,
        tickets_to_create: [],
        hold_items: []
      )
    end

    before do
      task.reenable
      allow(Ledgers::AnnualPlanRunner).to receive(:call).and_return(meeting)
    end

    it "runs without raising" do
      output = capture_stdout { task.invoke }
      payload = JSON.parse(output)

      expect(payload["operation"]).to eq("annual_plan")
      expect(payload.dig("meeting_ledger", "meeting_key")).to eq("annual_plan")
      expect(Ledgers::AnnualPlanRunner).to have_received(:call)
    end
  end

  describe "ledgers:detect_improvements" do
    let(:task) { Rake::Task["ledgers:detect_improvements"] }

    before do
      task.reenable
      allow(Ledgers::ImprovementDetector).to receive(:call).and_return(
        detected: 2,
        details: [ { ticket_id: 1, rule: "high_overdue_rate", title: "A" } ]
      )
      allow(Ledgers::ImprovementResolver).to receive(:call).and_return(
        resolved: 1,
        details: [ { ticket_id: 2, rule: "stale_service", title: "B" } ]
      )
    end

    it "outputs improvement detection and resolution summary" do
      output = capture_stdout { task.invoke }
      payload = JSON.parse(output)

      expect(payload["operation"]).to eq("detect_improvements")
      expect(payload.dig("improvements", "detected")).to eq(2)
      expect(payload.dig("improvements", "resolved")).to eq(1)
      expect(payload.dig("improvements", "details").size).to eq(2)
    end
  end

  def capture_stdout
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original_stdout
  end
end
