require "rails_helper"

RSpec.describe AiSns::ObservationCollector do
  describe ".call" do
    it "returns a hash with all expected keys" do
      now = Time.zone.parse("2026-04-12 12:00:00")

      empty_rel = instance_double(ActiveRecord::Relation)
      allow(empty_rel).to receive(:where).and_return(empty_rel)
      allow(empty_rel).to receive(:not).and_return(empty_rel)
      allow(empty_rel).to receive(:select).and_return(empty_rel)
      allow(empty_rel).to receive(:distinct).and_return(empty_rel)
      allow(empty_rel).to receive(:pluck).and_return([])
      allow(empty_rel).to receive(:count).and_return(0)
      allow(empty_rel).to receive(:sum).and_return(0)
      allow(empty_rel).to receive(:empty?).and_return(true)

      allow(AiPost).to receive(:where).and_return(empty_rel)
      allow(AiUser).to receive(:count).and_return(5)
      allow(AiUser).to receive_message_chain(:active, :count).and_return(4)
      allow(AiDmThread).to receive(:where).and_return(empty_rel)
      allow(UserAiLike).to receive(:where).and_return(empty_rel)
      allow(UserFavoriteAi).to receive(:where).and_return(empty_rel)
      allow(PostReport).to receive_message_chain(:status_pending, :count).and_return(0)
      allow(SolidQueue::FailedExecution).to receive(:count).and_return(0)
      allow(SolidQueue::RecurringTask).to receive(:count).and_return(0)
      allow(LlmBudgetTracker).to receive(:count).and_return(10)

      result = described_class.call(now: now)

      expect(result[:generated_at]).to eq(now.iso8601)
      expect(result[:window_hours]).to eq(24)
      expect(result).to have_key(:totals)
      expect(result).to have_key(:engagement)
      expect(result).to have_key(:trend_vs_yesterday)
      expect(result).to have_key(:operations)
      expect(result.dig(:operations, :llm_calls_today)).to eq(10)
    end
  end
end
