require "rails_helper"

RSpec.describe AiSns::ImprovementExecutor do
  describe ".call" do
    let(:analysis_result) do
      {
        "summary" => "summary",
        "quick_wins" => [
          {
            "title" => "投稿モチベーション再計算",
            "reason" => "活性化のため",
            "action" => { "type" => "enqueue_job", "job_class" => "PostMotivationCalculateJob" }
          }
        ],
        "feature_proposals" => [
          { "title" => "会話スレッド改善", "rationale" => "返信率を上げるため" }
        ]
      }
    end

    it "enqueues allowed quick-win jobs and sends Slack notification" do
      allow(PostMotivationCalculateJob).to receive(:perform_later)
      allow(SlackNotifierService).to receive(:notify)

      result = described_class.call(analysis_result: analysis_result)

      expect(PostMotivationCalculateJob).to have_received(:perform_later)
      expect(SlackNotifierService).to have_received(:notify)
      expect(result["applied_quick_wins"]).to eq(1)
      expect(result["feature_proposals_count"]).to eq(1)
    end

    it "skips unsupported job class" do
      unsupported = analysis_result.deep_dup
      unsupported["quick_wins"][0]["action"]["job_class"] = "UnknownJobClass"
      allow(SlackNotifierService).to receive(:notify)

      result = described_class.call(analysis_result: unsupported)

      expect(result["applied_quick_wins"]).to eq(0)
      expect(result["quick_win_results"].first["status"]).to eq("skipped")
    end
  end
end
