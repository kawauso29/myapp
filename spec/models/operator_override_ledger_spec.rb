require "rails_helper"

RSpec.describe OperatorOverrideLedger, type: :model do
  let(:valid_attrs) do
    {
      action: :halt_all,
      scope_level: :company,
      operator: "kawauso29",
      started_at: 1.hour.ago,
      reason: "emergency"
    }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:operator) }
    it { is_expected.to validate_presence_of(:started_at) }
    it { is_expected.to validate_presence_of(:reason) }

    it "requires service_id when scope_level is service" do
      record = described_class.new(
        valid_attrs.merge(action: :halt_service, scope_level: :service, service_id: nil)
      )
      expect(record).not_to be_valid
      expect(record.errors[:service_id]).to be_present
    end

    it "rejects lifted_at before started_at" do
      record = described_class.new(
        valid_attrs.merge(lifted_at: 2.hours.ago, started_at: 1.hour.ago)
      )
      expect(record).not_to be_valid
      expect(record.errors[:lifted_at]).to be_present
    end

    it "is valid when lifted_at >= started_at" do
      record = described_class.new(
        valid_attrs.merge(lifted_at: Time.current, started_at: 1.hour.ago)
      )
      expect(record).to be_valid
    end
  end

  describe ".currently_active" do
    it "includes halt_* records without lifted_at" do
      active = described_class.create!(valid_attrs)
      described_class.create!(valid_attrs.merge(lifted_at: Time.current))

      expect(described_class.currently_active).to contain_exactly(active)
    end

    it "excludes resume_* actions" do
      described_class.create!(valid_attrs.merge(action: :resume_all))
      expect(described_class.currently_active).to be_empty
    end
  end

  describe ".halted?" do
    context "when halt_all is active" do
      before { described_class.create!(valid_attrs) }

      it "returns true for any scope" do
        expect(described_class.halted?).to be true
        expect(described_class.halted?(scope_level: :service, service_id: "ai_sns")).to be true
      end
    end

    context "when halt_service is active for ai_sns" do
      before do
        described_class.create!(
          valid_attrs.merge(action: :halt_service, scope_level: :service, service_id: "ai_sns")
        )
      end

      it "returns true for matching service_id" do
        expect(described_class.halted?(service_id: "ai_sns")).to be true
      end

      it "returns false for other services" do
        expect(described_class.halted?(service_id: "other_service")).to be false
      end
    end

    context "when halt_scope is active for portfolio" do
      before do
        described_class.create!(
          valid_attrs.merge(action: :halt_scope, scope_level: :portfolio)
        )
      end

      it "returns true for matching scope_level" do
        expect(described_class.halted?(scope_level: :portfolio)).to be true
      end

      it "returns false for other scope_level" do
        expect(described_class.halted?(scope_level: :service)).to be false
      end
    end

    context "when no active halt exists" do
      it "returns false" do
        expect(described_class.halted?).to be false
      end
    end

    context "when halt is lifted" do
      before do
        described_class.create!(valid_attrs.merge(lifted_at: Time.current))
      end

      it "returns false" do
        expect(described_class.halted?).to be false
      end
    end
  end
end
