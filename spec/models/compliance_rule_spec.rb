require "rails_helper"

RSpec.describe ComplianceRule, type: :model do
  let(:valid_attrs) do
    {
      name: "PII email",
      law_domain: :pii,
      scope_level: :company,
      pattern: '[\w.+-]+@[\w-]+\.[\w.-]+',
      severity: :block,
      owner_role: :audit,
      enforced_at: 1.minute.ago
    }
  end

  describe "validations" do
    it "is valid with valid attributes" do
      expect(described_class.new(valid_attrs)).to be_valid
    end

    it "requires name/pattern/severity/owner_role" do
      record = described_class.new
      expect(record).not_to be_valid
      expect(record.errors[:name]).to be_present
      expect(record.errors[:pattern]).to be_present
      expect(record.errors[:severity]).to be_present
      expect(record.errors[:owner_role]).to be_present
    end
  end

  describe ".enforced" do
    it "excludes rules without enforced_at" do
      enforced = described_class.create!(valid_attrs)
      described_class.create!(valid_attrs.merge(name: "not yet", enforced_at: nil))
      expect(described_class.enforced).to contain_exactly(enforced)
    end

    it "excludes rules with future enforced_at" do
      described_class.create!(valid_attrs.merge(enforced_at: 1.hour.from_now))
      expect(described_class.enforced).to be_empty
    end
  end

  describe ".violations_for" do
    before { described_class.create!(valid_attrs) }

    it "returns matching enforced rule for text containing a violation" do
      violations = described_class.violations_for(
        "Contact me at alice@example.com please",
        scope_level: :company
      )
      expect(violations.size).to eq(1)
      expect(violations.first.blocking?).to be true
    end

    it "returns [] for text without matches" do
      expect(described_class.violations_for("clean", scope_level: :company)).to eq([])
    end

    it "skips rules with invalid regex gracefully" do
      described_class.create!(valid_attrs.merge(name: "bad regex", pattern: "("))
      expect {
        described_class.violations_for("anything", scope_level: :company)
      }.not_to raise_error
    end
  end

  describe "#compiled_pattern" do
    it "returns nil for invalid regex" do
      record = described_class.new(valid_attrs.merge(pattern: "("))
      expect(record.compiled_pattern).to be_nil
    end
  end
end
