require "rails_helper"

RSpec.describe AiSnsAutonomousImprovementJob, type: :job do
  describe "#perform" do
    it "runs observe -> analyze -> execute flow" do
      observation = { "totals" => { "posts_24h" => 10 } }
      analysis = { "summary" => "summary", "quick_wins" => [], "feature_proposals" => [] }
      execution = { "applied_quick_wins" => 0, "feature_proposals_count" => 0 }

      allow(AiSns::ObservationCollector).to receive(:call).and_return(observation)
      allow(AiSns::LlmAnalysisService).to receive(:call).with(observation: observation).and_return(analysis)
      allow(AiSns::ImprovementExecutor).to receive(:call).with(analysis_result: analysis).and_return(execution)

      result = described_class.perform_now

      expect(result[:observation]).to eq(observation)
      expect(result[:analysis]).to eq(analysis)
      expect(result[:execution]).to eq(execution)
    end
  end
end
