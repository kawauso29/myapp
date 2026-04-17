require "rails_helper"

RSpec.describe StopLedger, type: :model do
  it "is valid with default attributes" do
    expect(build(:stop_ledger)).to be_valid
  end

  it "rejects lifted_at earlier than started_at" do
    record = build(:stop_ledger, started_at: 1.hour.ago, lifted_at: 2.hours.ago)
    expect(record).not_to be_valid
    expect(record.errors[:lifted_at]).to be_present
  end

  it "lift! transitions to lifted with audit trail" do
    stop = create(:stop_ledger, status: :active)

    stop.lift!(by: "operator", reason: "KPI recovered")

    expect(stop.reload).to be_status_lifted
    expect(stop.lifted_by).to eq("operator")
    expect(stop.lift_reason).to eq("KPI recovered")
    expect(stop.lifted_at).to be_present
  end

  describe ".active_for" do
    it "filters by scope_level and service_id" do
      matching = create(:stop_ledger, scope_level: :service, service_id: "ai_sns", status: :active)
      create(:stop_ledger, scope_level: :service, service_id: "trading", status: :active)
      create(:stop_ledger, scope_level: :service, service_id: "ai_sns",
             status: :lifted, started_at: 2.hours.ago, lifted_at: 1.hour.ago,
             lifted_by: "operator", lift_reason: "recovered")

      expect(described_class.active_for(scope_level: :service, service_id: "ai_sns")).to contain_exactly(matching)
    end
  end

  describe "lifted validation" do
    it "requires lifted_at / lifted_by / lift_reason when status=lifted" do
      record = build(:stop_ledger, status: :lifted,
                     lifted_at: nil, lifted_by: nil, lift_reason: nil)
      expect(record).not_to be_valid
      expect(record.errors[:lifted_at]).to be_present
      expect(record.errors[:lifted_by]).to be_present
      expect(record.errors[:lift_reason]).to be_present
    end

    it "allows status=active without lifted fields" do
      expect(build(:stop_ledger, status: :active)).to be_valid
    end

    it "allows status=lifted with all audit fields filled" do
      record = build(:stop_ledger, status: :lifted,
                     started_at: 1.hour.ago,
                     lifted_at: Time.current, lifted_by: "operator", lift_reason: "recovered")
      expect(record).to be_valid
    end
  end
end
