require "rails_helper"

RSpec.describe Ledgers::PlanItemUpserter do
  describe ".call" do
    it "creates a TicketLedger with service_id-derived idempotency_key and linked_kpis" do
      ticket = described_class.call(
        service_id: "voice_app",
        item_key: "V1",
        title: "音声入力対応",
        priority: :high,
        category: "engagement",
        kpi_hypothesis: "DAU +5%"
      )

      expect(ticket).to be_persisted
      expect(ticket.idempotency_key).to eq("voice_app_plan:V1")
      expect(ticket.service_id).to eq("voice_app")
      expect(ticket).to be_scope_level_service
      expect(ticket).to be_operating_lane_weekly_improvement
      expect(ticket).to be_priority_high
      expect(ticket).to be_status_draft
      expect(ticket.linked_kpis).to eq([ "voice_app_plan:V1" ])
      expect(ticket.improvement_pattern_key).to eq("engagement")
      expect(ticket.kpi_hypothesis).to eq("DAU +5%")
      expect(ticket.source_meeting).to be_present
    end

    it "is idempotent for same service_id+item_key (updates in place)" do
      t1 = described_class.call(service_id: "ai_chat", item_key: "C1", title: "first", priority: :low)
      t2 = described_class.call(service_id: "ai_chat", item_key: "C1", title: "second", priority: :high)

      expect(t1.id).to eq(t2.id)
      expect(t2.title).to eq("second")
      expect(t2).to be_priority_high
      expect(TicketLedger.where(idempotency_key: "ai_chat_plan:C1").count).to eq(1)
    end

    it "preserves existing notes when called again without notes:" do
      described_class.call(service_id: "ai_sns", item_key: "N1", title: "with notes",
                           priority: :medium, notes: "memo")
      ticket = described_class.call(service_id: "ai_sns", item_key: "N1", title: "still here", priority: :medium)

      expect(ticket.notes).to eq("memo")
    end

    it "raises ArgumentError when required fields are blank" do
      expect {
        described_class.call(service_id: "", item_key: "X", title: "x")
      }.to raise_error(ArgumentError)
      expect {
        described_class.call(service_id: "s", item_key: "", title: "x")
      }.to raise_error(ArgumentError)
      expect {
        described_class.call(service_id: "s", item_key: "X", title: "")
      }.to raise_error(ArgumentError)
    end

    it "skips ENFORCE_TEMPLATE / lane_capacity / pr_guardrail / stop guards" do
      TicketLedger.enforce_template = true
      expect {
        described_class.call(service_id: "ai_sns", item_key: "G1", title: "guarded", priority: :medium)
      }.not_to raise_error
    ensure
      TicketLedger.enforce_template = false
    end

    it "uses ai_sns idempotency_key compatible with AiSnsPlanSync" do
      ticket = described_class.call(service_id: "ai_sns", item_key: "B2", title: "compat", priority: :medium)

      expect(ticket.idempotency_key).to eq("ai_sns_plan:B2")
      expect(ticket.idempotency_key).to eq(Ledgers::AiSnsPlanSync.idempotency_key_for("B2"))
    end
  end
end
