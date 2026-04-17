require "rails_helper"

RSpec.describe Reinforcements::ConflictResolver do
  describe ".resolve" do
    it "resolves unanimously when all approve" do
      decisions = [
        { role: "exec_planning", decision: "approve" },
        { role: "audit", decision: "approve" }
      ]
      result = described_class.resolve(action: :approve_ticket, scope: :service, decisions: decisions)

      expect(result.resolved).to be true
      expect(result.reason).to eq("unanimous_approve")
    end

    it "resolves unanimously when all reject" do
      decisions = [
        { role: "exec_planning", decision: "reject" },
        { role: "audit", decision: "reject" }
      ]
      result = described_class.resolve(action: :approve_ticket, scope: :service, decisions: decisions)

      expect(result.resolved).to be true
      expect(result.reason).to eq("unanimous_reject")
    end

    it "uses tiebreaker_role to resolve conflict" do
      create(:role_permission,
             role: :exec_audit, action: :approve_ticket, scope: :service,
             allowed: true, tiebreaker_role: :president)
      decisions = [
        { role: "exec_planning", decision: "approve" },
        { role: "audit", decision: "reject" },
        { role: "president", decision: "approve" }
      ]
      result = described_class.resolve(action: :approve_ticket, scope: :service, decisions: decisions)

      expect(result.resolved).to be true
      expect(result.tiebreaker_role).to eq("president")
      expect(result.reason).to eq("tiebreaker_decided")
    end

    it "returns unresolved when no tiebreaker defined" do
      decisions = [
        { role: "exec_planning", decision: "approve" },
        { role: "audit", decision: "reject" }
      ]
      result = described_class.resolve(action: :halt_service, scope: :company, decisions: decisions)

      expect(result.resolved).to be false
      expect(result.reason).to eq("no_tiebreaker_defined")
    end
  end
end
