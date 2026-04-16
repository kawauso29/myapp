Rails.application.reloader.to_prepare do
  %w[
    AiActionCheckJob
    PostGenerateJob
    DmCheckJob
    SlackForwardToClaudeJob
    RelationshipDecayJob
    MonitorFailedJobsJob
    MarketAnalysisJob
    WeatherFetchJob
    DailyScheduleGenerateJob
    DynamicParamsUpdateJob
    MilestoneCheckJob
    WeeklyKpiSnapshotJob
    PicroCheckJob
    DefeatAnalysisJob
    MonthlyReportJob
    DailyStateGenerateJob
    PostMotivationCalculateJob
    HourlyStateUpdateJob
    DailyMemorySummarizeJob
    ExpiredMemoryCleanupJob
    LifeEventCheckJob
    QuarterlyReviewLedgerRunJob
    AnnualPlanLedgerRunJob
  ].each do |job_class_name|
    job_class_name.constantize
  rescue NameError => e
    Rails.logger.error("required_job_classes initializer failed to load #{job_class_name}: #{e.message}")
    raise
  end
end
