require "rails_helper"

RSpec.describe KnowledgeLedger, type: :model do
  it "is valid with default attributes" do
    expect(build(:knowledge_ledger)).to be_valid
  end

  it "requires kind and title" do
    record = KnowledgeLedger.new
    record.valid?
    expect(record.errors.attribute_names).to include(:kind, :title)
  end

  describe "scopes" do
    it "active_adrs returns accepted ADRs only" do
      adr = create(:knowledge_ledger, kind: :adr, status: :accepted)
      create(:knowledge_ledger, kind: :adr, status: :draft)
      create(:knowledge_ledger, kind: :runbook, status: :accepted)

      expect(described_class.active_adrs).to contain_exactly(adr)
    end
  end
end

RSpec.describe HrEvaluationLedger, type: :model do
  it "is valid with default attributes" do
    expect(build(:hr_evaluation_ledger)).to be_valid
  end

  it "requires period_end >= period_start" do
    record = build(:hr_evaluation_ledger, period_start: Date.current, period_end: Date.current - 1.day)
    expect(record).not_to be_valid
    expect(record.errors[:period_end]).to be_present
  end

  it "rejects score outside 0..1" do
    expect(build(:hr_evaluation_ledger, score: 1.5)).not_to be_valid
    expect(build(:hr_evaluation_ledger, score: -0.1)).not_to be_valid
  end
end

RSpec.describe OrgChangeLedger, type: :model do
  it "is valid with default attributes" do
    expect(build(:org_change_ledger)).to be_valid
  end
end

RSpec.describe CustomerFeedbackLedger, type: :model do
  it "is valid with default attributes" do
    expect(build(:customer_feedback_ledger)).to be_valid
  end

  it "pending_triage scope returns only new_feedback status records" do
    pending = create(:customer_feedback_ledger, status: :new_feedback)
    create(:customer_feedback_ledger, status: :categorized)

    expect(described_class.pending_triage).to contain_exactly(pending)
  end
end

RSpec.describe PortfolioStrategyLedger, type: :model do
  it "is valid with default attributes" do
    expect(build(:portfolio_strategy_ledger)).to be_valid
  end

  it "requires unique strategy_key" do
    create(:portfolio_strategy_ledger, strategy_key: "fixed-key")
    duplicate = build(:portfolio_strategy_ledger, strategy_key: "fixed-key")
    expect(duplicate).not_to be_valid
  end

  it "requires period_end >= period_start when both are set" do
    record = build(:portfolio_strategy_ledger,
                   period_start: Date.current,
                   period_end: Date.current - 1.day)
    expect(record).not_to be_valid
  end
end
