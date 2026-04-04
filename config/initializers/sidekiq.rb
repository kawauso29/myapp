Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }

  config.on(:startup) do
    schedule_file = Rails.root.join("config", "schedule.yml")
    if File.exist?(schedule_file)
      Sidekiq::Cron::Job.load_from_hash YAML.load_file(schedule_file)
    end
  end

  config.death_handlers << ->(job, ex) do
    Rails.logger.error("[DeadJob] #{job['class']} failed permanently: #{ex.message}")
    SlackNotifierService.notify(
      text: ":skull: *Sidekiqジョブが永久に失敗しました*",
      color: :danger,
      fields: [
        { title: "ジョブクラス", value: job["class"] },
        { title: "エラー",       value: "#{ex.class}: #{ex.message}" },
        { title: "JID",          value: job["jid"] },
        { title: "試行回数",     value: job["retry_count"].to_s }
      ]
    )
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }
end
