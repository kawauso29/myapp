# LedgerV2::RunExecutor — すべての Runner の統一入口。
# Runner を直接呼ばず、必ずこれを経由する。
# 設計の正本: ledger_v2_detailed_design.txt §「LedgerV2::RunExecutor」
module LedgerV2
  class RunExecutor
    # Runner が返すべき結果の型。Runner 実装時は必ずこれを返す。
    RunnerResult = Struct.new(
      :created_ticket_count,
      :updated_ticket_count,
      :created_artifact_count,
      :created_event_count,
      :duplicate_prevented_count,
      keyword_init: true
    ) do
      def initialize(**)
        super
        self.created_ticket_count      ||= 0
        self.updated_ticket_count      ||= 0
        self.created_artifact_count    ||= 0
        self.created_event_count       ||= 0
        self.duplicate_prevented_count ||= 0
      end
    end

    def self.call(runner_name, dry_run: false, trigger_type: :schedule, triggered_by: nil, idempotency_key: nil, **args)
      new(
        runner_name:,
        dry_run:,
        trigger_type:,
        triggered_by:,
        idempotency_key:,
        args:
      ).call
    end

    def initialize(runner_name:, dry_run:, trigger_type:, triggered_by:, idempotency_key:, args:)
      @runner_name     = normalize_runner_name(runner_name)
      @dry_run         = dry_run
      @trigger_type    = trigger_type
      @triggered_by    = triggered_by
      @idempotency_key = idempotency_key
      @args            = args
      @started_at      = Time.current
    end

    def call
      # 同一 idempotency_key の Run がある場合は既存を返す（重複実行防止）。
      # 既存 Run の status が :failed / :blocked であっても返す。
      # 再実行が必要な場合は異なる idempotency_key を使うこと。
      if idempotency_key.present?
        existing = Run.find_by(idempotency_key:)
        return existing if existing
      end

      # FeatureFlag 確認（Ticket 4 で LedgerV2::Flags に置き換える）
      return create_skipped_run(:feature_disabled) unless flags_enabled?

      # CircuitBreaker 確認（Ticket 5 で LedgerV2::CircuitBreaker に置き換える）
      blocked_reason = circuit_breaker_reason
      return create_blocked_run(blocked_reason) if blocked_reason

      run = Run.create!(
        runner_name:,
        status:          :running,
        dry_run:,
        trigger_type:,
        triggered_by:,
        idempotency_key:,
        started_at:
      )

      runner_result = runner_class.call(run:, dry_run:, **args)

      run.update!(
        status:                    :success,
        finished_at:               Time.current,
        duration_ms:               calculate_duration,
        created_ticket_count:      runner_result.created_ticket_count,
        updated_ticket_count:      runner_result.updated_ticket_count,
        created_artifact_count:    runner_result.created_artifact_count,
        created_event_count:       runner_result.created_event_count,
        duplicate_prevented_count: runner_result.duplicate_prevented_count
      )

      run
    rescue => e
      run&.update!(
        status:        :failed,
        error_class:   e.class.name,
        error_message: e.message,
        finished_at:   Time.current
      )
      raise
    end

    private

    attr_reader :runner_name, :dry_run, :trigger_type, :triggered_by, :idempotency_key, :args, :started_at

    # Ticket 4 (LedgerV2::Flags) 完成まで常に true を返す。
    def flags_enabled?
      true
    end

    # Ticket 5 (LedgerV2::CircuitBreaker) 完成まで常に nil を返す（blocked なし）。
    def circuit_breaker_reason
      nil
    end

    def runner_class
      "LedgerV2::#{runner_name}".constantize
    rescue NameError
      raise ArgumentError, "LedgerV2::#{runner_name} は存在しません。runner_name に正しいクラス名を指定してください（例: :daily_runner → LedgerV2::DailyRunner）"
    end

    def calculate_duration
      ((Time.current - started_at) * 1000).round
    end

    def normalize_runner_name(name)
      name.to_s.camelize
    end

    def create_skipped_run(reason)
      Run.create!(
        runner_name:,
        status:         :skipped,
        dry_run:,
        trigger_type:,
        triggered_by:,
        idempotency_key:,
        skipped_reason: reason.to_s,
        started_at:,
        finished_at:    Time.current
      )
    end

    def create_blocked_run(reason)
      Run.create!(
        runner_name:,
        status:         :blocked,
        dry_run:,
        trigger_type:,
        triggered_by:,
        idempotency_key:,
        skipped_reason: reason.to_s,
        started_at:,
        finished_at:    Time.current
      )
    end
  end
end
