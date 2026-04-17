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
  end
end
