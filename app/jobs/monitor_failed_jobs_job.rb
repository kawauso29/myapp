class MonitorFailedJobsJob < ApplicationJob
  queue_as :default

  def perform
    return unless Rails.env.production?

    failed_executions = SolidQueue::FailedExecution.order(created_at: :desc).limit(10)
    failed_executions.each do |execution|
      # 既に通知済みのジョブはスキップ
      next if execution.updated_at < 1.minute.ago

      notify_slack(execution)
    end
  end

  private

  def notify_slack(execution)
    SlackNotifierService.notify(
      text: ":skull: *SolidQueueジョブ失敗*",
      color: :danger,
      fields: [
        { title: "ジョブクラス", value: execution.job_class },
        { title: "エラー",       value: execution.error.truncate(300) },
        { title: "ジョブID",     value: execution.job_id.to_s }
      ]
    )
  end
end
