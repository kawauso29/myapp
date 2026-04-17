require "rails_helper"

RSpec.describe AuditDecisionLedger, type: :model do
  it "is valid with an approval reason_code" do
    expect(build(:audit_decision_ledger, decision: :approve, reason_code: "approved_no_reservation")).to be_valid
  end

  it "requires reason_code" do
    record = build(:audit_decision_ledger, reason_code: nil)
    expect(record).not_to be_valid
    expect(record.errors[:reason_code]).to be_present
  end

  it "rejects approval with a non-approval reason_code" do
    record = build(:audit_decision_ledger, decision: :approve, reason_code: "security_risk")
    expect(record).not_to be_valid
    expect(record.errors[:reason_code]).to be_present
  end

  it "rejects reject with an approval reason_code" do
    record = build(:audit_decision_ledger, decision: :reject, reason_code: "approved_no_reservation")
    expect(record).not_to be_valid
    expect(record.errors[:reason_code]).to be_present
  end

  it "allows reject with a proper reason_code" do
    expect(build(:audit_decision_ledger, decision: :reject, reason_code: "security_risk")).to be_valid
  end

  it "has a non_approvals scope" do
    create(:audit_decision_ledger, decision: :approve, reason_code: "approved_no_reservation")
    rejected = create(:audit_decision_ledger, decision: :reject, reason_code: "security_risk")

    expect(described_class.non_approvals).to contain_exactly(rejected)
  end
end
