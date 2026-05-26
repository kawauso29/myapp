# frozen_string_literal: true

require "rails_helper"

RSpec.describe Linestamp::SeedApplication, type: :model do
  describe "validations" do
    it "requires seed_id" do
      sa = described_class.new(state: "pending")
      expect(sa).not_to be_valid
      expect(sa.errors[:seed_id]).to be_present
    end

    it "requires state in STATES" do
      sa = described_class.new(seed_id: "x", state: "unknown")
      expect(sa).not_to be_valid
      expect(sa.errors[:state]).to be_present
    end

    it "enforces uniqueness of seed_id" do
      described_class.create!(seed_id: "uniq_test", state: "pending")
      dup = described_class.new(seed_id: "uniq_test", state: "pending")
      expect(dup).not_to be_valid
    end
  end

  describe "#mark_applied!" do
    it "transitions to applied state" do
      sa = described_class.create!(seed_id: "apply_test", state: "pending")
      sa.mark_applied!(summary: "OK")
      expect(sa.reload.state).to eq("applied")
      expect(sa.applied_at).to be_present
      expect(sa.result_summary).to eq("OK")
    end
  end

  describe "#mark_failed!" do
    it "transitions to failed state with error" do
      sa = described_class.create!(seed_id: "fail_test", state: "pending")
      sa.mark_failed!(error: "Something broke")
      expect(sa.reload.state).to eq("failed")
      expect(sa.error_message).to eq("Something broke")
    end
  end

  describe "scopes" do
    before do
      described_class.create!(seed_id: "s1", state: "pending")
      described_class.create!(seed_id: "s2", state: "applied", applied_at: Time.current)
      described_class.create!(seed_id: "s3", state: "failed", error_message: "err")
    end

    it ".pending returns pending only" do
      expect(described_class.pending.pluck(:seed_id)).to eq(%w[s1])
    end

    it ".applied returns applied only" do
      expect(described_class.applied.pluck(:seed_id)).to eq(%w[s2])
    end

    it ".failed returns failed only" do
      expect(described_class.failed.pluck(:seed_id)).to eq(%w[s3])
    end
  end
end
