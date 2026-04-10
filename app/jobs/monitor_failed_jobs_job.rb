class MonitorFailedJobsJob < ApplicationJob
  queue_as :default

  def perform
    return unless Rails.env.production?

    # 前回チェック時刻をキャッシュから取得（初回は1時間前）
    last_check = Rails.cache.read("monitor_failed_jobs:last_check") || 1.hour.ago
    now = Time.current

    failed_executions = SolidQueue::FailedExecution
      .where(created_at: last_check..)
      .order(created_at: :desc)
      .limit(20)

    failed_executions.each do |execution|
      notify_slack(execution)
    end

    Rails.cache.write("monitor_failed_jobs:last_check", now, expires_in: 1.hour)
  rescue => e
    Rails.logger.error("[MonitorFailedJobsJob] Error: #{e.message}")
    SlackNotifierService.notify(
      text: ":skull: *MonitorFailedJobsJob エラー*",
      color: :danger,
      fields: [ { title: "エラー", value: e.message.truncate(300) } ]
    )
  end

  private

  def notify_slack(execution)
    job = execution.job
    error_data = execution.error || {}
    error_summary = "#{error_data['exception_class']}: #{error_data['message']}".truncate(300)

    SlackNotifierService.notify(
      text: ":skull: *バックグラウンドジョブ失敗*",
      color: :danger,
      fields: [
        { title: "ジョブクラス", value: job.class_name },
        { title: "エラー",       value: error_summary },
        { title: "ジョブID",     value: job.active_job_id.to_s }
      ]
    )
  end
end
