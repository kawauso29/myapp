require "rails_helper"

RSpec.describe Ledgers::AiSnsPlanSync do
  describe ".call" do
    let(:initiative) do
      DevInitiative.create!(
        item_key: "B2",
        title: "AI SNS 改善: B2",
        category: "engagement",
        priority: :high,
        status: :todo,
        kpi_hypothesis: "DAU が +5% になる",
        pr_branch: "copilot/ai-sns-b2"
      )
    end

    it "creates a TicketLedger mirror with the canonical idempotency_key" do
      ticket = described_class.call(initiative)

      expect(ticket).to be_persisted
      expect(ticket.idempotency_key).to eq("ai_sns_plan:B2")
      expect(ticket.title).to eq("AI SNS 改善: B2")
      expect(ticket.ticket_type).to eq("improvement")
      expect(ticket).to be_scope_level_service
      expect(ticket.service_id).to eq("ai_sns")
      expect(ticket).to be_operating_lane_weekly_improvement
      expect(ticket).to be_priority_high
      expect(ticket).to be_status_draft
      expect(ticket.linked_kpis).to eq([ "ai_sns_plan:B2" ])
      expect(ticket.pr_branch).to eq("copilot/ai-sns-b2")
      expect(ticket.kpi_hypothesis).to eq("DAU が +5% になる")
      expect(ticket.improvement_pattern_key).to eq("engagement")
      expect(ticket.source_meeting).to be_present
    end

    it "is idempotent (does not create duplicates)" do
      ticket1 = described_class.call(initiative)
      ticket2 = described_class.call(initiative)

      expect(ticket1.id).to eq(ticket2.id)
      expect(TicketLedger.where(idempotency_key: "ai_sns_plan:B2").count).to eq(1)
    end

    it "maps DevInitiative status changes to TicketLedger status" do
      described_class.call(initiative)

      initiative.update!(status: :in_progress, started_at: Time.current)
      ticket = described_class.call(initiative)
      expect(ticket).to be_status_executing

      initiative.update!(status: :done, completed_at: Time.current, kpi_result: "DAU +6%")
      ticket = described_class.call(initiative)
      expect(ticket).to be_status_completed
      expect(ticket.kpi_result).to eq("DAU +6%")
      expect(ticket.due_date).to eq(initiative.completed_at.to_date)
    end

    it "skips ENFORCE_TEMPLATE / lane_capacity / pr_guardrail / stop guards" do
      TicketLedger.enforce_template = true
      expect { described_class.call(initiative) }.not_to raise_error
    ensure
      TicketLedger.enforce_template = false
    end
  end

  describe ".create_plan_item!" do
    it "creates a TicketLedger directly without requiring DevInitiative as input" do
      ticket = described_class.create_plan_item!(
        item_key: "X1",
        title: "新規施策 X1",
        priority: :high,
        category: "engagement",
        kpi_hypothesis: "DAU +3%",
        notes: "実装メモ"
      )

      expect(ticket).to be_persisted
      expect(ticket.idempotency_key).to eq("ai_sns_plan:X1")
      expect(ticket.title).to eq("新規施策 X1")
      expect(ticket).to be_priority_high
      expect(ticket).to be_status_draft
      expect(ticket).to be_operating_lane_weekly_improvement
      expect(ticket.improvement_pattern_key).to eq("engagement")
      expect(ticket.kpi_hypothesis).to eq("DAU +3%")
      expect(ticket.linked_kpis).to eq([ "ai_sns_plan:X1" ])
    end

    it "stores notes directly on the TicketLedger (PR4: no longer routed via DevInitiative)" do
      ticket = described_class.create_plan_item!(
        item_key: "X2", title: "notes 保管", priority: :medium, notes: "メモ本文"
      )

      expect(ticket.notes).to eq("メモ本文")
      expect(TicketLedger.where(idempotency_key: "ai_sns_plan:X2").count).to eq(1)
      # DevInitiative 側には書き込まれない（mirror も DI 起点なので発火しない）。
      expect(DevInitiative.find_by(item_key: "X2")).to be_nil
    end

    it "is idempotent when called twice with the same item_key" do
      t1 = described_class.create_plan_item!(item_key: "X3", title: "first", priority: :low)
      t2 = described_class.create_plan_item!(item_key: "X3", title: "second", priority: :high)

      expect(t1.id).to eq(t2.id)
      expect(t2.title).to eq("second")
      expect(t2).to be_priority_high
      expect(TicketLedger.where(idempotency_key: "ai_sns_plan:X3").count).to eq(1)
    end

    it "raises ArgumentError when item_key or title is blank" do
      expect {
        described_class.create_plan_item!(item_key: "", title: "x")
      }.to raise_error(ArgumentError)

      expect {
        described_class.create_plan_item!(item_key: "X4", title: "")
      }.to raise_error(ArgumentError)
    end
  end

  describe "DevInitiative#after_save hook" do
    it "automatically mirrors on save" do
      DevInitiative.create!(item_key: "A1", title: "auto mirror", priority: :medium, status: :todo)

      ticket = TicketLedger.find_by(idempotency_key: "ai_sns_plan:A1")
      expect(ticket).to be_present
      expect(ticket.title).to eq("auto mirror")
    end

    it "does not roll back DevInitiative save when mirroring fails" do
      allow(described_class).to receive(:call).and_raise(StandardError, "boom")

      expect {
        DevInitiative.create!(item_key: "A2", title: "guarded", priority: :low, status: :todo)
      }.not_to raise_error

      expect(DevInitiative.find_by(item_key: "A2")).to be_present
    end
  end
end
