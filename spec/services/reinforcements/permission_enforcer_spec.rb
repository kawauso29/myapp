require "rails_helper"

RSpec.describe Reinforcements::PermissionEnforcer do
  describe ".enforce!" do
    it "raises PermissionDenied by default (no allowed row)" do
      expect {
        described_class.enforce!(role: :dev, action: :halt_service, scope: :service, service_id: "ai_sns")
      }.to raise_error(Reinforcements::PermissionDenied)
    end

    it "passes when a matching allowed row exists" do
      create(:role_permission,
             role: :exec_audit, action: :approve_ticket, scope: :company, allowed: true)
      expect(
        described_class.enforce!(role: :exec_audit, action: :approve_ticket, scope: :company)
      ).to be true
    end
  end

  describe ".permitted?" do
    it "returns true for matching allowed row" do
      create(:role_permission,
             role: :exec_audit, action: :approve_ticket, scope: :company, allowed: true)
      expect(described_class.permitted?(role: :exec_audit, action: :approve_ticket, scope: :company))
        .to be true
    end
  end

  describe ".dual_approval_required?" do
    it "returns true when allowed row requires dual approval" do
      create(:role_permission,
             role: :exec_audit, action: :halt_service, scope: :service,
             allowed: true, requires_dual_approval: true, approver_role: :president)
      expect(
        described_class.dual_approval_required?(role: :exec_audit, action: :halt_service, scope: :service)
      ).to be true
    end

    it "returns false when no requires_dual_approval row exists" do
      expect(
        described_class.dual_approval_required?(role: :dev, action: :create_ticket, scope: :service)
      ).to be false
    end
  end
end
