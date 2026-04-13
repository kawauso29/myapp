class AiSnsAutonomousImprovementJob < ApplicationJob
  include JobErrorHandling

  queue_as :low

  def perform
    observation = AiSns::ObservationCollector.call
    analysis = AiSns::LlmAnalysisService.call(observation: observation)
    execution = AiSns::ImprovementExecutor.call(analysis_result: analysis)

    ImprovementLog.record!(observation: observation, analysis: analysis, execution: execution)

    Rails.logger.info(
      "[AiSnsAutonomousImprovementJob] completed " \
      "quick_wins=#{execution['applied_quick_wins']} " \
      "feature_proposals=#{execution['feature_proposals_count']}"
    )

    {
      observation: observation,
      analysis: analysis,
      execution: execution
    }
  end
end
