require "rails_helper"

RSpec.describe ServiceTimeAxisSetting, type: :model do
  describe "validations" do
    subject(:setting) do
      described_class.new(
        service_id: "ai_sns",
        cadence: :daily,
        interval_seconds: 1800
      )
    end

    it { is_expected.to be_valid }

    it "requires service_id" do
      setting.service_id = nil
      expect(setting).not_to be_valid
      expect(setting.errors[:service_id]).to be_present
    end

    it "requires cadence" do
      setting.cadence = nil
      expect(setting).not_to be_valid
      expect(setting.errors[:cadence]).to be_present
    end

    it "requires interval_seconds" do
      setting.interval_seconds = nil
      expect(setting).not_to be_valid
      expect(setting.errors[:interval_seconds]).to be_present
    end

    it "requires interval_seconds > 0" do
      setting.interval_seconds = 0
      expect(setting).not_to be_valid
      expect(setting.errors[:interval_seconds]).to be_present
    end

    it "enforces uniqueness of cadence per service_id" do
      described_class.create!(service_id: "ai_sns", cadence: :daily, interval_seconds: 1800)
      duplicate = described_class.new(service_id: "ai_sns", cadence: :daily, interval_seconds: 3600)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:cadence]).to be_present
    end
  end

  describe ".interval_for" do
    it "returns the interval as Duration when record exists" do
      described_class.create!(service_id: "test_svc", cadence: :weekly, interval_seconds: 7200)
      result = described_class.interval_for(service_id: "test_svc", cadence: :weekly)
      expect(result).to eq(7200.seconds)
    end

    it "returns nil when no record exists" do
      result = described_class.interval_for(service_id: "missing_svc", cadence: :weekly)
      expect(result).to be_nil
    end
  end

  describe "enum cadence" do
    it "defines all 6 cadences" do
      expect(described_class.cadences.keys).to match_array(%w[daily weekly monthly quarterly annual long_term])
    end
  end
end
