require "rails_helper"

RSpec.describe OrganizationRole, type: :model do
  describe "validations" do
    subject(:role) do
      described_class.new(
        role_key: "test_role",
        display_name: "Test Role",
        scope_level: :service,
        category: :department
      )
    end

    it { is_expected.to be_valid }

    it "requires role_key" do
      role.role_key = nil
      expect(role).not_to be_valid
    end

    it "requires display_name" do
      role.display_name = nil
      expect(role).not_to be_valid
    end

    it "requires scope_level" do
      role.scope_level = nil
      expect(role).not_to be_valid
    end

    it "requires category" do
      role.category = nil
      expect(role).not_to be_valid
    end

    it "enforces uniqueness of role_key" do
      described_class.create!(role_key: "unique_role", display_name: "Unique", scope_level: :company, category: :executive)
      duplicate = described_class.new(role_key: "unique_role", display_name: "Dup", scope_level: :service, category: :department)
      expect(duplicate).not_to be_valid
    end

    it "validates role_key format (lowercase with underscores)" do
      role.role_key = "Invalid-Key"
      expect(role).not_to be_valid
      expect(role.errors[:role_key]).to be_present
    end
  end

  describe ".active" do
    it "returns only active roles" do
      active = described_class.create!(role_key: "active_role", display_name: "Active", scope_level: :company, category: :executive, active: true)
      described_class.create!(role_key: "inactive_role", display_name: "Inactive", scope_level: :company, category: :executive, active: false)
      expect(described_class.active).to contain_exactly(active)
    end
  end

  describe ".validate_roles" do
    before do
      described_class.create!(role_key: "planning", display_name: "Planning", scope_level: :service, category: :department)
      described_class.create!(role_key: "dev", display_name: "Dev", scope_level: :service, category: :department)
    end

    it "returns empty array when all roles are known" do
      expect(described_class.validate_roles(%w[planning dev])).to eq([])
    end

    it "returns unknown role keys" do
      expect(described_class.validate_roles(%w[planning unknown_role])).to eq(["unknown_role"])
    end

    it "returns empty array for blank input" do
      expect(described_class.validate_roles([])).to eq([])
      expect(described_class.validate_roles(nil)).to eq([])
    end
  end
end
