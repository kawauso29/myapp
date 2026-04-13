require "rails_helper"

RSpec.describe AiSnsAutonomousImprovementJob, type: :job do
  describe "#perform" do
    it "runs observe -> analyze -> execute flow and records improvement log" do
      observation = { "totals" => { "posts_24h" => 10 } }
      analysis = { "summary" => "summary", "quick_wins" => [], "feature_proposals" => [] }
      execution = { "applied_quick_wins" => 0, "quick_win_results" => [], "feature_proposals_count" => 0, "created_pr_numbers" => [] }

      allow(AiSns::ObservationCollector).to receive(:call).and_return(observation)
      allow(AiSns::LlmAnalysisService).to receive(:call).with(observation: observation).and_return(analysis)
      allow(AiSns::ImprovementExecutor).to receive(:call).with(analysis_result: analysis).and_return(execution)
      allow(ImprovementLog).to receive(:record!)

      result = described_class.perform_now

      expect(result[:observation]).to eq(observation)
      expect(result[:analysis]).to eq(analysis)
      expect(result[:execution]).to eq(execution)
      expect(ImprovementLog).to have_received(:record!).with(
        observation: observation,
        analysis: analysis,
        execution: execution
      )
    end
  end
end
