class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  rescue_from StandardError do |exception|
    notify_slack_on_job_error(exception)
    raise exception
  end

  private

  def notify_slack_on_job_error(exception)
    return unless Rails.env.production?
    SlackNotifierService.notify(
      text: ":skull: *バックグラウンドジョブエラー*",
      color: :danger,
      fields: [
        { title: "ジョブクラス", value: self.class.name },
        { title: "エラー",       value: "#{exception.class}: #{exception.message.truncate(300)}" },
        { title: "ジョブID",     value: job_id },
        { title: "引数",         value: arguments.map(&:to_s).join(", ").truncate(200) }
      ]
    )
  end
end
