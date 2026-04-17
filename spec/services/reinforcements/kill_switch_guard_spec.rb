require "rails_helper"

RSpec.describe Reinforcements::KillSwitchGuard do
  describe ".halted?" do
    it "returns false when no halt rows exist" do
      expect(described_class.halted?).to be false
    end

    it "returns true when halt_all is active" do
      OperatorOverrideLedger.create!(
        action: :halt_all, scope_level: :company,
        operator: "kawauso29", started_at: 1.minute.ago, reason: "test"
      )
      expect(described_class.halted?).to be true
    end
  end

  describe ".ensure_not_halted!" do
    it "raises Halted when kill-switch is active for the service" do
      OperatorOverrideLedger.create!(
        action: :halt_service, scope_level: :service, service_id: "ai_sns",
        operator: "kawauso29", started_at: 1.minute.ago, reason: "emergency"
      )
      expect {
        described_class.ensure_not_halted!(scope_level: :service, service_id: "ai_sns")
      }.to raise_error(Reinforcements::Halted)
    end

    it "returns true when not halted" do
      expect(described_class.ensure_not_halted!(scope_level: :service, service_id: "ai_sns")).to be true
    end
  end

  describe ".guarded" do
    it "yields the block when not halted" do
      expect(described_class.guarded { 42 }).to eq(42)
    end

    it "does not yield when halted" do
      OperatorOverrideLedger.create!(
        action: :halt_all, scope_level: :company,
        operator: "kawauso29", started_at: 1.minute.ago, reason: "test"
      )
      called = false
      result = described_class.guarded { called = true }
      expect(result).to be_nil
      expect(called).to be false
    end
  end
end
