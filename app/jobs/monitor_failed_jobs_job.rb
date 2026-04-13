class MonitorFailedJobsJob < ApplicationJob
  queue_as :default

  def perform
    return unless Rails.env.production?

    last_check = Rails.cache.read("monitor_failed_jobs:last_check") || 1.hour.ago
    now = Time.current

    failed_scope = SolidQueue::FailedExecution.where(created_at: last_check..)
    failed_scope = failed_scope.where(discarded_at: nil) if SolidQueue::FailedExecution.column_names.include?("discarded_at")
    failed_executions = failed_scope.order(created_at: :desc).limit(100)

    # 常にlast_checkを更新（通知失敗時も再通知しないよう）
    Rails.cache.write("monitor_failed_jobs:last_check", now, expires_in: 2.hours)

    return if failed_executions.empty?

    # jobがnilのレコード（job削除済み）はスキップ
    valid_executions = failed_executions.select { |ex| ex.job.present? }
    return if valid_executions.empty?

    # デプロイ直後の一時的なクラスロードエラーを除外・自動破棄
    # UnknownJobClassError かつ現在クラスがロード可能 → デプロイ時の瞬間的な失敗なのでアラート不要
    valid_executions = valid_executions.reject do |ex|
      discard_transient_unknown_class_error?(ex)
    end
    return if valid_executions.empty?

    # 同じジョブクラス＋エラー種別でグループ化してまとめて1通知
    grouped = valid_executions.group_by do |ex|
      error_data = normalized_error_data(ex.error)
      exception_class = error_data["exception_class"].presence || "UnknownException"
      "#{resolved_job_class_name(ex.job, error_data)}::#{exception_class}"
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
    error_data = normalized_error_data(first.error)
    exception_class = error_data["exception_class"].presence || "UnknownException"
    error_summary = "#{exception_class}: #{error_data['message']}".to_s.truncate(300)
    count = executions.size

    SlackNotifierService.notify(
      text: ":skull: *バックグラウンドジョブ失敗*#{count > 1 ? "（#{count}件まとめ）" : ""}",
      color: :danger,
      fields: [
        { title: "ジョブクラス", value: resolved_job_class_name(job, error_data) },
        { title: "エラー",       value: error_summary },
        { title: "件数",         value: count.to_s }
      ]
    )
  end

  def discard_transient_unknown_class_error?(execution)
    error_data = normalized_error_data(execution.error)
    return false unless unknown_job_class_error?(error_data)

    job_class_name = resolved_job_class_name(execution.job, error_data)
    return false if job_class_name.blank?
    return false unless job_class_name.safe_constantize

    execution.discard
    true
  rescue StandardError
    false
  end

  def unknown_job_class_error?(error_data)
    exception_class = error_data["exception_class"].to_s
    message = error_data["message"].to_s
    exception_class == "ActiveJob::UnknownJobClassError" ||
      message.include?("UnknownJobClassError") ||
      message.include?("Failed to instantiate job")
  end

  def normalized_error_data(error)
    case error
    when Hash
      error.stringify_keys
    when String
      parsed = JSON.parse(error)
      parsed.is_a?(Hash) ? parsed.stringify_keys : { "message" => error }
    else
      if error.respond_to?(:to_h)
        error.to_h.stringify_keys
      else
        {}
      end
    end
  rescue JSON::ParserError
    { "message" => error.to_s }
  end

  def resolved_job_class_name(job, error_data = {})
    return "unknown" unless job

    job_class_name = job.class_name
    return job_class_name unless job_class_name == "ActiveJob::QueueAdapters::SolidQueueAdapter::JobWrapper"

    payload = job.arguments
    payload = JSON.parse(payload) if payload.is_a?(String)
    payload = payload.first if payload.is_a?(Array)
    wrapper_job_class = payload["job_class"] || payload[:job_class] if payload.is_a?(Hash)
    wrapper_job_class.presence || extract_missing_class_name(error_data["message"].to_s) || job_class_name
  rescue JSON::ParserError
    extract_missing_class_name(error_data["message"].to_s) || job_class_name
  end

  def extract_missing_class_name(message)
    message.match(/class [`"]([^`"]+)[`"] doesn't exist/)&.captures&.first
  end
end
