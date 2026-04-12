require "rails_helper"

RSpec.describe AiSns::LlmAnalysisService do
  describe ".call" do
    let(:observation) do
      {
        totals: { posts_24h: 10 },
        operations: { pending_reports: 0 },
        engagement: { reply_rate_24h: 0.2 }
      }
    end

    it "normalizes LLM JSON response" do
      allow(LlmClient).to receive(:call).and_return(
        {
          summary: "観察結果の要約",
          quick_wins: [
            {
              title: "投稿モチベーション再計算",
              reason: "投稿数が少ないため",
              action: { type: "enqueue_job", job_class: "PostMotivationCalculateJob" }
            }
          ],
          feature_proposals: [
            { title: "会話スレッド改善", rationale: "返信率向上のため" }
          ]
        }.to_json
      )

      result = described_class.call(observation: observation)

      expect(result["summary"]).to eq("観察結果の要約")
      expect(result["quick_wins"].size).to eq(1)
      expect(result["quick_wins"].first.dig("action", "job_class")).to eq("PostMotivationCalculateJob")
      expect(result["feature_proposals"].first["title"]).to eq("会話スレッド改善")
    end

    it "falls back when LLM response is invalid JSON" do
      allow(LlmClient).to receive(:call).and_return("invalid json")

      result = described_class.call(observation: observation)

      expect(result["summary"]).to include("観察データ")
      expect(result["quick_wins"]).to be_an(Array)
      expect(result["feature_proposals"]).to be_an(Array)
    end
  end
end
