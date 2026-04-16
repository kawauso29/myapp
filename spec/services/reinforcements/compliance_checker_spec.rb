require "rails_helper"

RSpec.describe Reinforcements::ComplianceChecker do
  describe ".check" do
    it "returns empty result for clean text" do
      create(:compliance_rule, severity: :block)
      result = described_class.check("nothing sensitive", scope_level: :company)
      expect(result.violations).to eq([])
      expect(result).not_to be_blocked
    end

    it "captures block-level violation for PII email" do
      create(:compliance_rule, severity: :block)
      result = described_class.check("contact alice@example.com", scope_level: :company)
      expect(result).to be_blocked
      expect(result.blocks.size).to eq(1)
    end

    it "categorizes violations by severity" do
      create(:compliance_rule, name: "warn rule", severity: :warn, pattern: "foo")
      create(:compliance_rule, name: "audit rule", severity: :audit, pattern: "bar")
      result = described_class.check("foo bar", scope_level: :company)
      expect(result.warnings.map(&:name)).to include("warn rule")
      expect(result.audits.map(&:name)).to include("audit rule")
      expect(result).not_to be_blocked
    end
  end

  describe ".check!" do
    it "raises BlockingViolation when block-level rule matches" do
      create(:compliance_rule, severity: :block)
      expect {
        described_class.check!("email: bob@example.com", scope_level: :company)
      }.to raise_error(Reinforcements::BlockingViolation)
    end

    it "does not raise for warn-only matches" do
      create(:compliance_rule, severity: :warn, pattern: "alert")
      expect {
        described_class.check!("alert text", scope_level: :company)
      }.not_to raise_error
    end
  end
end
