Rails.application.reloader.to_prepare do
  %w[
    SlackForwardToClaudeJob
    PicroCheckJob
    Linestamp::ComposeBrandPromptJob
    Linestamp::ComposePackSheetPromptJob
    Linestamp::ComposeStampPromptsJob
  ].each do |job_class_name|
    job_class_name.constantize
  rescue NameError => e
    Rails.logger.error("required_job_classes initializer failed to load #{job_class_name}: #{e.message}")
    raise
  end
end
