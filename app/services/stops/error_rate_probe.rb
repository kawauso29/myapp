module Stops
  # Phase 2 補強 / 穴⑦: `error_spike` 判定ソースの抽象化。
  #
  # 現状の `Stops::ConditionEvaluator#evaluate_error_spike` は SolidQueue の
  # `FailedExecution` 件数を「アプリエラー指標」の代理値として用いている。
  # しかしこれは「ジョブが落ちた」事実であって「エンドユーザー影響」ではないため、
  # 将来的には Nginx 5xx / アプリログのエラーレート / 外部監視（Sentry 等）と
  # 差し替えられるよう、本クラスでソースをカプセル化する。
  #
  # 使い方:
  #   probe = Stops::ErrorRateProbe.default
  #   probe.failure_count(window_minutes: 60)
  #   probe.source_label  # => "solid_queue_failed_executions"
  #
  # 将来的な差し替え方:
  #   Stops::ErrorRateProbe.register(:nginx_5xx, ->(window_minutes) { ... })
  #   Rails.application.config.stops_error_rate_probe = :nginx_5xx
  class ErrorRateProbe
    DEFAULT_PROBE_KEY = :solid_queue_failed_executions

    class << self
      def registry
        @registry ||= {
          DEFAULT_PROBE_KEY => method(:solid_queue_failure_count)
        }
      end

      def register(key, callable)
        registry[key.to_sym] = callable
      end

      def default
        new(probe_key: configured_probe_key)
      end

      def configured_probe_key
        key = (Rails.application.config.respond_to?(:stops_error_rate_probe) ? Rails.application.config.stops_error_rate_probe : nil) ||
              ENV["STOPS_ERROR_RATE_PROBE"]
        key.present? ? key.to_sym : DEFAULT_PROBE_KEY
      end

      # SolidQueue 失敗件数（既定 probe）。テーブル未作成環境では 0 を返す。
      def solid_queue_failure_count(window_minutes)
        return 0 unless ActiveRecord::Base.connection.table_exists?("solid_queue_failed_executions")

        SolidQueue::FailedExecution.where(created_at: window_minutes.minutes.ago..).count
      rescue StandardError => e
        Rails.logger.warn("[Stops::ErrorRateProbe] solid_queue probe failed: #{e.class}: #{e.message}")
        0
      end
    end

    def initialize(probe_key: DEFAULT_PROBE_KEY)
      @probe_key = probe_key.to_sym
    end

    def source_label
      @probe_key.to_s
    end

    def failure_count(window_minutes:)
      callable = self.class.registry[@probe_key] || self.class.registry[DEFAULT_PROBE_KEY]
      callable.call(window_minutes).to_i
    rescue StandardError => e
      Rails.logger.warn("[Stops::ErrorRateProbe] probe=#{@probe_key} failed: #{e.class}: #{e.message}")
      0
    end
  end
end
