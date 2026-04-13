require "rails_helper"

RSpec.describe ImprovementLog, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:observation) }
  end

  describe ".record!" do
    let(:observation) { { "totals" => { "posts_24h" => 10 } } }
    let(:analysis)    { { "summary" => "good", "quick_wins" => [], "feature_proposals" => [{ "title" => "A" }] } }
    let(:execution)   { { "applied_quick_wins" => 1, "quick_win_results" => [], "created_pr_numbers" => [42] } }

    it "creates a log record with all fields" do
      log = described_class.record!(observation: observation, analysis: analysis, execution: execution)

      expect(log).to be_persisted
      expect(log.summary).to eq("good")
      expect(log.applied_quick_wins).to eq(1)
      expect(log.created_pr_numbers).to eq([42])
    end

    it "returns nil and logs on error" do
      allow(described_class).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)
      expect(Rails.logger).to receive(:error).with(/ImprovementLog/)

      result = described_class.record!(observation: observation, analysis: analysis, execution: execution)
      expect(result).to be_nil
    end
  end

  describe ".recent_summaries" do
    it "returns formatted strings for recent logs" do
      create(:improvement_log, summary: "テスト所見", created_at: 1.hour.ago)

      summaries = described_class.recent_summaries(limit: 1)

      expect(summaries.first).to match(/テスト所見/)
    end
  end

  describe ".recent_feature_titles" do
    it "returns a set of recently proposed feature titles" do
      create(:improvement_log, feature_proposals: [{ "title" => "タイムライン改善" }, { "title" => "画像生成" }])
      create(:improvement_log, feature_proposals: [{ "title" => "音声DM" }])

      titles = described_class.recent_feature_titles(limit: 5)

      expect(titles).to include("タイムライン改善", "画像生成", "音声DM")
    end
  end
end
