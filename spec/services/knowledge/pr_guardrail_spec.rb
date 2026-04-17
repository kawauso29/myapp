require "rails_helper"

RSpec.describe Knowledge::PrGuardrail do
  describe ".check" do
    it "passes when risk_level is low" do
      ticket = create(:ticket_ledger, risk_level: :low, ticket_type: :improvement, service_id: "ai_sns")
      result = described_class.check(ticket: ticket)
      expect(result.passed?).to be(true)
    end

    it "fails for a high-risk ticket when no ADR / Runbook exists" do
      ticket = create(:ticket_ledger, risk_level: :high, ticket_type: :improvement, service_id: "ai_sns")
      result = described_class.check(ticket: ticket)
      expect(result.passed?).to be(false)
      expect(result.missing_artifacts).to contain_exactly("adr", "runbook")
    end

    it "passes for a high-risk ticket when ADR and Runbook exist and are tagged with the service" do
      ticket = create(:ticket_ledger, risk_level: :high, ticket_type: :improvement, service_id: "ai_sns")
      create(:knowledge_ledger, kind: :adr, status: :accepted, tags: { service_id: "ai_sns" })
      create(:knowledge_ledger, kind: :runbook, status: :accepted, tags: { service_id: "ai_sns" })

      result = described_class.check(ticket: ticket)
      expect(result.passed?).to be(true)
    end

    it "requires ADR / Runbook for investigation tickets regardless of risk_level" do
      ticket = create(:ticket_ledger, risk_level: :low, ticket_type: :investigation, service_id: "ai_sns")
      result = described_class.check(ticket: ticket)
      expect(result.passed?).to be(false)
    end

    it "does not falsely pass for an unsaved ticket when a KnowledgeLedger has source_ticket_id IS NULL" do
      # 以前の実装は before_create 経由で呼ばれると @ticket.id が nil となり、
      # `OR source_ticket_id: nil` が広くマッチして誤って passed を返していた。
      unrelated_service_adr = create(:knowledge_ledger, kind: :adr, status: :accepted,
                                     tags: { service_id: "other_service" })
      expect(unrelated_service_adr.source_ticket_id).to be_nil

      ticket = build(:ticket_ledger, risk_level: :high, ticket_type: :improvement, service_id: "ai_sns")
      expect(ticket.id).to be_nil

      result = described_class.check(ticket: ticket)
      expect(result.passed?).to be(false)
      expect(result.missing_artifacts).to include("adr")
    end
  end
end
