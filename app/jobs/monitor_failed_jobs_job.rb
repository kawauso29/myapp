class MonitorFailedJobsJob < ApplicationJob
  queue_as :default

  def perform
    return unless Rails.env.production?

    # 過去の最後チェック時刻を取得（初回はnil）
    last_check = Rails.cache.read("monitor_failed_jobs:last_check")
    now = Time.current

    # 新しい失敗ジョブを照会
    sql = if last_check.present?
      <<~SQL
        SELECT job_class, error, job_id
        FROM solid_queue_failed_executions
        WHERE created_at > '#{last_check.iso8601}'
        ORDER BY created_at DESC
        LIMIT 20
      SQL
    else
      # 初回実行時は直近1時間
      <<~SQL
        SELECT job_class, error, job_id
        FROM solid_queue_failed_executions
        WHERE created_at > NOW() - INTERVAL '1 hour'
        ORDER BY created_at DESC
        LIMIT 10
      SQL
    end

    results = ActiveRecord::Base.connection.execute(sql)

    results.each do |row|
      notify_slack(row)
    end

    # 次回のチェック時刻を保存
    Rails.cache.write("monitor_failed_jobs:last_check", now, expires_in: 1.hour)
  rescue => e
    Rails.logger.error("[MonitorFailedJobsJob] Error: #{e.message}")
    SlackNotifierService.notify(
      text: ":skull: *MonitorFailedJobsJob エラー*",
      color: :danger,
      fields: [{ title: "エラー", value: e.message.truncate(300) }]
    )
  end

  private

  def notify_slack(row)
    SlackNotifierService.notify(
      text: ":skull: *バックグラウンドジョブ失敗*",
      color: :danger,
      fields: [
        { title: "ジョブクラス", value: row["job_class"].to_s },
        { title: "エラー",       value: row["error"].to_s.truncate(300) },
        { title: "ジョブID",     value: row["job_id"].to_s }
      ]
    )
  end
end
