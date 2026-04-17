require "rails_helper"

RSpec.describe GithubMapping::RiskBasedFlow do
  describe ".for" do
    it "returns low-risk flow for unknown risk" do
      flow = described_class.for("unknown")
      expect(flow[:auto_merge_eligible]).to be true
      expect(flow[:copilot_autonomous]).to be true
    end

    it "returns correct flow for high risk" do
      flow = described_class.for("high")
      expect(flow[:required_approvals]).to eq(2)
      expect(flow[:auto_merge_eligible]).to be false
      expect(flow[:audit_review_required]).to be true
      expect(flow[:copilot_autonomous]).to be false
    end

    it "returns correct flow for medium risk" do
      flow = described_class.for("medium")
      expect(flow[:required_approvals]).to eq(1)
      expect(flow[:auto_merge_eligible]).to be true
    end
  end

  describe ".required_checks" do
    it "returns ci_pass only for low risk" do
      ticket = create(:ticket_ledger, risk_level: :low)
      checks = described_class.required_checks(ticket)

      expect(checks).to eq([:ci_pass])
    end

    it "includes audit_review and manual_merge for high risk" do
      ticket = create(:ticket_ledger, risk_level: :high)
      checks = described_class.required_checks(ticket)

      expect(checks).to include(:ci_pass)
      expect(checks).to include(:reviewer_approve)
      expect(checks).to include(:audit_review)
      expect(checks).to include(:manual_merge)
    end
  end

  describe ".auto_merge_eligible?" do
    it "is true for low risk" do
      expect(described_class.auto_merge_eligible?("low")).to be true
    end

    it "is false for high risk" do
      expect(described_class.auto_merge_eligible?("high")).to be false
    end
  end
end
