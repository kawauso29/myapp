class MonitorFailedJobsJob < ApplicationJob
  queue_as :default

  def perform
    return unless Rails.env.production?

    last_check = Rails.cache.read("monitor_failed_jobs:last_check") || 1.hour.ago
    now = Time.current

    failed_executions = SolidQueue::FailedExecution
      .where(created_at: last_check..)
      .order(created_at: :desc)
      .limit(100)

    # 常にlast_checkを更新（通知失敗時も再通知しないよう）
    Rails.cache.write("monitor_failed_jobs:last_check", now, expires_in: 2.hours)

    return if failed_executions.empty?

    # jobがnilのレコード（job削除済み）はスキップ
    valid_executions = failed_executions.select { |ex| ex.job.present? }
    return if valid_executions.empty?

    # 同じジョブクラス＋エラー種別でグループ化してまとめて1通知
    grouped = valid_executions.group_by do |ex|
      error_data = ex.error || {}
      "#{ex.job.class_name}::#{error_data['exception_class']}"
    end

    grouped.each do |_key, executions|
      notify_slack_grouped(executions)
    end
  rescue => e
    Rails.logger.error("[MonitorFailedJobsJob] Error: #{e.message}")
  end

  private

  def notify_slack_grouped(executions)
    first = executions.first
    job = first.job
    error_data = first.error || {}
    error_summary = "#{error_data['exception_class']}: #{error_data['message']}".truncate(300)
    count = executions.size

    SlackNotifierService.notify(
      text: ":skull: *バックグラウンドジョブ失敗*#{count > 1 ? "（#{count}件まとめ）" : ""}",
      color: :danger,
      fields: [
        { title: "ジョブクラス", value: job.class_name },
        { title: "エラー",       value: error_summary },
        { title: "件数",         value: count.to_s }
      ]
    )
  end
end
