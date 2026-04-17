require "rails_helper"

RSpec.describe Org::ChangeProposer do
  describe ".propose" do
    it "creates a proposed OrgChangeLedger with idempotency key" do
      change = described_class.propose(
        change_type: :role_create,
        subject_role: "growth_lead",
        scope_level: :service,
        service_id: "ai_sns",
        diff: { "add" => { "role" => "growth_lead" } },
        rationale: "Q2 KPI 改善"
      )

      expect(change).to be_persisted
      expect(change).to be_status_proposed
      expect(change.change_type).to eq("role_create")
      expect(change.idempotency_key).to start_with("org_change:role_create:service:ai_sns")
    end

    it "is idempotent within the same day" do
      first = described_class.propose(change_type: :role_create, subject_role: "growth_lead",
                                      scope_level: :service, service_id: "ai_sns")
      second = described_class.propose(change_type: :role_create, subject_role: "growth_lead",
                                       scope_level: :service, service_id: "ai_sns")
      expect(second.id).to eq(first.id)
    end
  end

  describe "state transitions" do
    let(:change) do
      described_class.propose(change_type: :role_create, subject_role: "growth_lead",
                              scope_level: :service, service_id: "ai_sns")
    end

    it "moves proposed -> approved -> in_effect" do
      described_class.approve(change, by: "ceo", reason: "annual_plan で承認")
      change.reload
      expect(change).to be_status_approved
      expect(change.diff["approved_by"]).to eq("ceo")

      described_class.activate(change, effective_from: Date.current)
      change.reload
      expect(change).to be_status_in_effect
      expect(change.effective_from).to eq(Date.current)
    end

    it "rejects activate before approve" do
      expect {
        described_class.activate(change)
      }.to raise_error(Org::ChangeProposer::InvalidTransition)
    end

    it "rolls back from in_effect" do
      described_class.approve(change, by: "ceo")
      described_class.activate(change)
      described_class.rollback(change, reason: "1Q 試行で効果薄")
      change.reload
      expect(change).to be_status_rolled_back
      expect(change.diff["rollback_reason"]).to eq("1Q 試行で効果薄")
    end

    it "rejects rollback from proposed" do
      expect {
        described_class.rollback(change, reason: "early withdraw")
      }.to raise_error(Org::ChangeProposer::InvalidTransition)
    end
  end
end
