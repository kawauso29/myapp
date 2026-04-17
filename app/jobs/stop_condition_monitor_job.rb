class StopConditionMonitorJob < ApplicationJob
  include Ledgers::JobIdempotency
  queue_as :default

  # Phase 33: 15 分ごとに自動停止条件を評価する recurring job。
  # Rails.cache ベースの冪等性で 1 時間内に重複で走らないようにする（cron の多重実行対策）。
  def perform(scope_level: :service, service_id: "ai_sns")
    self.class.with_job_idempotency("stop_monitor:#{scope_level}:#{service_id}:#{Time.current.strftime('%Y%m%d%H')}", ttl: 1.hour) do
      Stops::ConditionEvaluator.call(scope_level: scope_level, service_id: service_id)
    end
  end
end
