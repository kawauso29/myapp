require "rails_helper"

RSpec.describe Ledgers::IdempotencyKey do
  describe ".for_meeting" do
    it "returns a deterministic key from prefix, parts and date" do
      key = described_class.for_meeting(prefix: "weekly_dept", parts: [ "ai_sns" ], on: Date.new(2026, 4, 17))

      expect(key).to eq("weekly_dept:ai_sns:2026-04-17")
    end

    it "defaults to today when on is omitted" do
      expected_today = Date.current.iso8601
      key = described_class.for_meeting(prefix: "monthly_ops")

      expect(key).to eq("monthly_ops:#{expected_today}")
    end

    it "stringifies non-string parts such as years and quarter labels" do
      key = described_class.for_meeting(
        prefix: "quarterly_review",
        parts: [ 2026, "q2" ],
        on: Date.new(2026, 6, 30)
      )

      expect(key).to eq("quarterly_review:2026:q2:2026-06-30")
    end

    it "drops blank segments" do
      key = described_class.for_meeting(prefix: "weekly_dept", parts: [ nil, "" ], on: Date.new(2026, 4, 17))

      expect(key).to eq("weekly_dept:2026-04-17")
    end

    context "with cadence:" do
      it "uses Ledgers::TimeAxis.slot_token instead of date for the trailing segment" do
        at = Time.utc(2026, 4, 19, 13, 30, 0)
        allow(Time).to receive(:current).and_return(at)

        key = described_class.for_meeting(prefix: "weekly_dept", parts: [ "ai_sns" ], cadence: :weekly)

        # weekly = 4 時間 slot → [12:00, 16:00)
        expect(key).to eq("weekly_dept:ai_sns:2026-04-19T12:00:00Z")
      end

      it "produces the same key for two calls within the same cadence slot (idempotent)" do
        allow(Time).to receive(:current).and_return(Time.utc(2026, 4, 19, 0, 5, 0))
        key_a = described_class.for_meeting(prefix: "monthly_ops", cadence: :monthly)

        allow(Time).to receive(:current).and_return(Time.utc(2026, 4, 19, 11, 59, 59))
        key_b = described_class.for_meeting(prefix: "monthly_ops", cadence: :monthly)

        expect(key_a).to eq(key_b)
      end

      it "produces different keys for calls across the cadence slot boundary" do
        allow(Time).to receive(:current).and_return(Time.utc(2026, 4, 19, 11, 59, 59))
        key_a = described_class.for_meeting(prefix: "monthly_ops", cadence: :monthly)

        allow(Time).to receive(:current).and_return(Time.utc(2026, 4, 19, 12, 0, 1))
        key_b = described_class.for_meeting(prefix: "monthly_ops", cadence: :monthly)

        expect(key_a).not_to eq(key_b)
      end
    end
  end
end
