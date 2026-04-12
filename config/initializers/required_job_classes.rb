Rails.application.reloader.to_prepare do
  %w[
    AiActionCheckJob
    PostGenerateJob
    SlackForwardToClaudeJob
    RelationshipDecayJob
    MonitorFailedJobsJob
    MarketAnalysisJob
  ].each(&:constantize)
end
