class StopConditionMonitorJob < ApplicationJob
  include Ledgers::JobIdempotency
  queue_as :default

  # Phase 33: 15 分ごとに自動停止条件を評価する recurring job。
  # Rails.cache ベースの冪等性で 1 時間内に重複で走らないようにする（cron の多重実行対策）。
  #
  # Phase 2 補強 / 穴⑥: scope_level / service_id を引数で渡せば従来通り単一 scope の評価。
  # 引数なしで呼ばれた場合（recurring からのデフォルト）は、company スコープと
  # 既知の全 service_id について順に評価する（multi-scope monitoring）。
  #
  # Phase 2 補強 / 穴①: 評価後に `lift_resolved!` を呼んで条件解消済み Stop を自動解除する。
  def perform(scope_level: nil, service_id: nil)
    if scope_level.nil? && service_id.nil?
      perform_for_all_scopes
    else
      perform_for_scope(scope_level: scope_level || :service, service_id: service_id || "ai_sns")
    end
  end

  private

  def perform_for_all_scopes
    # 1. company スコープ（全社）
    perform_for_scope(scope_level: :company, service_id: nil)

    # 2. service スコープ：ServiceLedger 由来の active service_id 全件
    service_ids_for_monitoring.each do |sid|
      perform_for_scope(scope_level: :service, service_id: sid)
    end
  end

  def perform_for_scope(scope_level:, service_id:)
    cache_key = "stop_monitor:#{scope_level}:#{service_id || 'all'}:#{Time.current.strftime('%Y%m%d%H')}"
    self.class.with_job_idempotency(cache_key, ttl: 1.hour) do
      evaluator = Stops::ConditionEvaluator.new(scope_level: scope_level, service_id: service_id)
      evaluator.call
      evaluator.lift_resolved!
    end
  end

  # ServiceLedger#status_active が active なサービスを対象にする。
  # ServiceLedger 未デプロイ環境やテスト環境では空配列で安全にフォールバック。
  def service_ids_for_monitoring
    return [] unless defined?(ServiceLedger)

    ServiceLedger.respond_to?(:status_active) ? ServiceLedger.status_active.pluck(:service_id) : ServiceLedger.pluck(:service_id)
  rescue StandardError => e
    Rails.logger.warn("[StopConditionMonitorJob] service_id enumeration failed: #{e.class}: #{e.message}")
    []
  end
end
