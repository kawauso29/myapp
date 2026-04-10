Rails.application.config.after_initialize do
  # SolidQueueのスレッドレベルエラー（UnknownJobClassErrorなど）をSlackに通知
  # rescue_fromはjob実行前に発生するエラーをキャッチできないためここで設定
  SolidQueue.handle_thread_error = lambda do |error|
    Rails.logger.error("[SolidQueue] Thread error: #{error.class}: #{error.message}")
    next unless Rails.env.production?

    SlackNotifierService.notify(
      text: ":skull: *SolidQueueジョブエラー*",
      color: :danger,
      fields: [
        { title: "エラークラス", value: error.class.to_s },
        { title: "エラー",       value: error.message.to_s.truncate(300) }
      ]
    )
  end
end
