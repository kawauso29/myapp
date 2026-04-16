require "rails_helper"

RSpec.describe RolePermission, type: :model do
  let(:valid_attrs) do
    {
      role: :exec_audit,
      action: :approve_ticket,
      scope: :company,
      allowed: true
    }
  end

  describe "validations" do
    it "is valid with valid attributes" do
      expect(described_class.new(valid_attrs)).to be_valid
    end

    it "requires role, action, and scope" do
      record = described_class.new
      expect(record).not_to be_valid
      expect(record.errors[:role]).to be_present
      expect(record.errors[:action]).to be_present
      expect(record.errors[:scope]).to be_present
    end

    it "requires approver_role when requires_dual_approval is true" do
      record = described_class.new(valid_attrs.merge(requires_dual_approval: true))
      expect(record).not_to be_valid
      expect(record.errors[:approver_role]).to be_present
    end

    it "enforces uniqueness on (role, action, scope, service_id_pattern)" do
      described_class.create!(valid_attrs)
      duplicate = described_class.new(valid_attrs)
      expect(duplicate).not_to be_valid
    end
  end

  describe ".permitted?" do
    it "returns false when no allowed row exists (default deny)" do
      expect(described_class.permitted?(role: :dev, action: :halt_service, scope: :service)).to be false
    end

    it "returns true when an allowed row matches" do
      described_class.create!(valid_attrs)
      expect(
        described_class.permitted?(role: :exec_audit, action: :approve_ticket, scope: :company)
      ).to be true
    end

    it "respects service_id_pattern globs" do
      described_class.create!(
        valid_attrs.merge(scope: :service, service_id_pattern: "ai_*")
      )

      expect(
        described_class.permitted?(role: :exec_audit, action: :approve_ticket, scope: :service, service_id: "ai_sns")
      ).to be true
      expect(
        described_class.permitted?(role: :exec_audit, action: :approve_ticket, scope: :service, service_id: "other")
      ).to be false
    end
  end
end
