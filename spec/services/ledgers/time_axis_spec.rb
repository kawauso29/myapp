require "rails_helper"

RSpec.describe Ledgers::TimeAxis do
  describe "INTERVALS" do
    it "defines the 6 fixed compressed cadences from the design spec" do
      # 設計書 §11 / `thu_apr_16_2026_自律運営型ai企業体の設計.md` line 2309
      expect(described_class::INTERVALS).to eq(
        daily: 30.minutes,
        weekly: 4.hours,
        monthly: 12.hours,
        quarterly: 2.days,
        annual: 7.days,
        long_term: 28.days
      )
    end
  end

  describe ".interval_for" do
    it "returns the duration for a known cadence symbol" do
      expect(described_class.interval_for(:weekly)).to eq(4.hours)
    end

    it "accepts string cadence" do
      expect(described_class.interval_for("monthly")).to eq(12.hours)
    end

    it "raises ArgumentError for unknown cadence" do
      expect { described_class.interval_for(:bogus) }.to raise_error(ArgumentError, /Unknown cadence/)
    end
  end

  describe ".slot_start" do
    it "truncates the time to the start of the cadence interval" do
      at = Time.utc(2026, 4, 19, 13, 30, 0)
      # weekly = 4 時間 → 13:30 は [12:00, 16:00) の slot
      expect(described_class.slot_start(:weekly, at: at)).to eq(Time.utc(2026, 4, 19, 12, 0, 0))
    end

    it "groups two times in the same monthly slot to the same start" do
      a = Time.utc(2026, 4, 19, 0, 5, 0)
      b = Time.utc(2026, 4, 19, 11, 59, 59)
      # monthly = 12 時間 → どちらも [00:00, 12:00) slot
      expect(described_class.slot_start(:monthly, at: a)).to eq(described_class.slot_start(:monthly, at: b))
    end

    it "splits two times across cadence interval boundary into different slots" do
      a = Time.utc(2026, 4, 19, 11, 59, 59)
      b = Time.utc(2026, 4, 19, 12, 0, 0)
      expect(described_class.slot_start(:monthly, at: a)).not_to eq(described_class.slot_start(:monthly, at: b))
    end
  end

  describe ".slot_token" do
    it "returns ISO8601 string of the slot start" do
      at = Time.utc(2026, 4, 19, 13, 30, 0)
      expect(described_class.slot_token(:weekly, at: at)).to eq("2026-04-19T12:00:00Z")
    end
  end
end
