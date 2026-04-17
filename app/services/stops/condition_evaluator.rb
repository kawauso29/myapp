module Stops
  # Phase 33 / 補強7: ルール駆動の自動停止を評価し、必要なら StopLedger を起票する。
  #
  # 現時点のルール:
  #   - KPI grade が critical になったら kpi_breach で停止
  #   - OperatorOverrideLedger で halt_* が active なら manual_escalation として記録（冪等）
  #   - 当月 CostLedger 合計が閾値（`COST_RUNAWAY_MONTHLY_JPY` 環境変数 or 既定値）を
  #     超えたら cost_runaway で停止
  #   - SolidQueue 失敗ジョブが直近ウィンドウ内に閾値超で積まれたら error_spike で停止
  #   - AuditDecisionLedger.reason_code=security_risk が直近 24h 以内に記録されたら
  #     security_incident で停止
  #   - 対象サービスに適用される block-severity ComplianceRule が存在すれば
  #     compliance_violation で停止
  class ConditionEvaluator
    Result = Struct.new(:created, :existing, keyword_init: true)

    # Phase 33 / §18: cost_runaway の既定月間閾値。`COST_RUNAWAY_MONTHLY_JPY` で上書き可能。
    DEFAULT_COST_RUNAWAY_MONTHLY_JPY = 100_000

    # error_spike 判定: 直近この分数以内の SolidQueue 失敗数をカウントする。
    ERROR_SPIKE_WINDOW_MINUTES = 60
    # error_spike 判定: 失敗件数がこの値以上なら stop を起票する。`ERROR_SPIKE_THRESHOLD` で上書き可。
    DEFAULT_ERROR_SPIKE_THRESHOLD = 5

    # security_incident 判定: decided_at がこの時間以内の security_risk 判定を検索する。
    SECURITY_INCIDENT_WINDOW_HOURS = 24

    def self.call(**args)
      new(**args).call
    end

    def initialize(scope_level: :service, service_id: "ai_sns")
      @scope_level = scope_level
      @service_id = service_id
    end

    def call
      created = []
      existing = StopLedger.active_for(scope_level: @scope_level, service_id: @service_id).to_a

      created.concat(evaluate_kpi_breach(existing))
      created.concat(evaluate_manual_escalation(existing))
      created.concat(evaluate_cost_runaway(existing))
      created.concat(evaluate_error_spike(existing))
      created.concat(evaluate_security_incident(existing))
      created.concat(evaluate_compliance_violation(existing))

      Result.new(created: created, existing: existing)
    end

    private

    def evaluate_kpi_breach(existing)
      critical_kpis.map do |kpi|
        key = stop_key(kind: "kpi_critical", detail: kpi.kpi_key)
        next if existing.any? { |s| s.idempotency_key == key }

        StopLedger.create!(
          trigger_type: :kpi_breach,
          trigger_detail: "KPI #{kpi.kpi_key} grade=critical",
          scope_level: @scope_level,
          service_id: @service_id,
          status: :active,
          started_at: Time.current,
          evidence: { kpi_key: kpi.kpi_key, current_value: kpi.current_value, thresholds: kpi.thresholds, grade: kpi.grade },
          idempotency_key: key
        )
      end.compact
    end

    # OperatorOverrideLedger で halt_* が有効なら、対応する StopLedger を 1 件だけ記録する。
    def evaluate_manual_escalation(existing)
      return [] unless operator_halted?

      key = stop_key(kind: "operator_halt", detail: halt_detail)
      return [] if existing.any? { |s| s.idempotency_key == key }

      [ StopLedger.create!(
        trigger_type: :manual_escalation,
        trigger_detail: "operator halt active: #{halt_detail}",
        scope_level: @scope_level,
        service_id: @service_id,
        status: :active,
        started_at: Time.current,
        evidence: { halted_by: "operator_override_ledger", detail: halt_detail },
        idempotency_key: key
      ) ]
    end

    # 当月のサービス単位コスト合計が閾値を超えたら cost_runaway として記録する。
    def evaluate_cost_runaway(existing)
      return [] unless @scope_level == :service && @service_id.present?

      threshold = cost_runaway_threshold
      return [] if threshold.nil? || threshold <= 0

      total = Reinforcements::CostRecorder.monthly_total(service_id: @service_id)
      return [] if total.to_f < threshold.to_f

      key = stop_key(kind: "cost_runaway", detail: Date.current.strftime("%Y-%m"))
      return [] if existing.any? { |s| s.idempotency_key == key }

      [ StopLedger.create!(
        trigger_type: :cost_runaway,
        trigger_detail: "monthly cost #{total.to_i} JPY exceeds threshold #{threshold.to_i}",
        scope_level: @scope_level,
        service_id: @service_id,
        status: :active,
        started_at: Time.current,
        evidence: { monthly_total_jpy: total.to_f, threshold_jpy: threshold.to_f, month: Date.current.strftime("%Y-%m") },
        idempotency_key: key
      ) ]
    rescue StandardError => e
      Rails.logger.warn("[Stops::ConditionEvaluator] cost_runaway check failed: #{e.class} #{e.message}")
      []
    end

    # SolidQueue の失敗ジョブ数が直近 ERROR_SPIKE_WINDOW_MINUTES 以内に閾値を超えたら停止する。
    # 外部エラー監視ストリームが未整備な現状で、内部ジョブ失敗を代理指標として用いる。
    # `ERROR_SPIKE_THRESHOLD` 環境変数で閾値を変更可能。
    def evaluate_error_spike(existing)
      return [] unless error_spike_table_exists?

      threshold = error_spike_threshold
      window = ERROR_SPIKE_WINDOW_MINUTES.minutes.ago
      count = SolidQueue::FailedExecution.where(created_at: window..).count
      return [] if count < threshold

      key = stop_key(kind: "error_spike", detail: "#{Time.current.strftime('%Y%m%d%H%M').first(11)}0")
      return [] if existing.any? { |s| s.idempotency_key == key }

      [ StopLedger.create!(
        trigger_type: :error_spike,
        trigger_detail: "#{count} failed jobs in last #{ERROR_SPIKE_WINDOW_MINUTES}min (threshold=#{threshold})",
        scope_level: @scope_level,
        service_id: @service_id,
        status: :active,
        started_at: Time.current,
        evidence: { failed_count: count, window_minutes: ERROR_SPIKE_WINDOW_MINUTES, threshold: threshold },
        idempotency_key: key
      ) ]
    rescue StandardError => e
      Rails.logger.warn("[Stops::ConditionEvaluator] error_spike check failed: #{e.class} #{e.message}")
      []
    end

    # 直近 SECURITY_INCIDENT_WINDOW_HOURS 以内に reason_code=security_risk の
    # AuditDecisionLedger が記録されていたら security_incident 停止を起票する。
    def evaluate_security_incident(existing)
      return [] unless security_risk_audit_exists?

      key = stop_key(kind: "security_incident", detail: Date.current.iso8601)
      return [] if existing.any? { |s| s.idempotency_key == key }

      [ StopLedger.create!(
        trigger_type: :security_incident,
        trigger_detail: "security_risk audit decision recorded in last #{SECURITY_INCIDENT_WINDOW_HOURS}h",
        scope_level: @scope_level,
        service_id: @service_id,
        status: :active,
        started_at: Time.current,
        evidence: { reason_code: "security_risk", window_hours: SECURITY_INCIDENT_WINDOW_HOURS,
                    scope_level: @scope_level.to_s, service_id: @service_id },
        idempotency_key: key
      ) ]
    rescue StandardError => e
      Rails.logger.warn("[Stops::ConditionEvaluator] security_incident check failed: #{e.class} #{e.message}")
      []
    end

    # 対象サービスに適用される severity=:block の ComplianceRule が 1 件でも存在すれば
    # compliance_violation 停止を起票する。
    def evaluate_compliance_violation(existing)
      return [] unless compliance_block_rule_exists?

      key = stop_key(kind: "compliance_violation", detail: Date.current.iso8601)
      return [] if existing.any? { |s| s.idempotency_key == key }

      [ StopLedger.create!(
        trigger_type: :compliance_violation,
        trigger_detail: "active block-severity ComplianceRule applicable to service_id=#{@service_id}",
        scope_level: @scope_level,
        service_id: @service_id,
        status: :active,
        started_at: Time.current,
        evidence: { scope_level: @scope_level.to_s, service_id: @service_id, check: "compliance_block_rule" },
        idempotency_key: key
      ) ]
    rescue StandardError => e
      Rails.logger.warn("[Stops::ConditionEvaluator] compliance_violation check failed: #{e.class} #{e.message}")
      []
    end

    # ---- helpers ----------------------------------------------------------------

    def operator_halted?
      OperatorOverrideLedger.halted?(scope_level: @scope_level, service_id: @service_id)
    rescue StandardError => e
      Rails.logger.warn("[Stops::ConditionEvaluator] operator_halt check failed: #{e.class} #{e.message}")
      false
    end

    def halt_detail
      "#{@scope_level}/#{@service_id || 'all'}"
    end

    def cost_runaway_threshold
      raw = ENV["COST_RUNAWAY_MONTHLY_JPY"]
      return DEFAULT_COST_RUNAWAY_MONTHLY_JPY if raw.blank?

      Float(raw)
    rescue ArgumentError, TypeError
      DEFAULT_COST_RUNAWAY_MONTHLY_JPY
    end

    def critical_kpis
      return [] unless KpiLedger.column_names.include?("grade")

      kpis = KpiLedger.status_active.where(grade: KpiLedger.grades[:critical])
      kpis = kpis.where(service_id: @service_id) if @scope_level == :service
      kpis
    end

    def error_spike_table_exists?
      ActiveRecord::Base.connection.table_exists?("solid_queue_failed_executions")
    rescue StandardError
      false
    end

    def error_spike_threshold
      raw = ENV["ERROR_SPIKE_THRESHOLD"]
      return DEFAULT_ERROR_SPIKE_THRESHOLD if raw.blank?

      Integer(raw)
    rescue ArgumentError, TypeError
      DEFAULT_ERROR_SPIKE_THRESHOLD
    end

    def security_risk_audit_exists?
      window = SECURITY_INCIDENT_WINDOW_HOURS.hours.ago
      scope = AuditDecisionLedger.where(reason_code: "security_risk")
                                 .where(decided_at: window..)
      if @scope_level == :service && @service_id.present?
        scope = scope.where(scope_level: AuditDecisionLedger.scope_levels[:service],
                            service_id: @service_id)
      end
      scope.exists?
    rescue StandardError => e
      Rails.logger.warn("[Stops::ConditionEvaluator] security_risk check failed: #{e.class} #{e.message}")
      false
    end

    def compliance_block_rule_exists?
      base = ComplianceRule.enforced.where(severity: ComplianceRule.severities[:block])
      if @scope_level == :service && @service_id.present?
        base.applicable_to(scope_level: :service, service_id: @service_id).exists?
      else
        base.exists?
      end
    rescue StandardError => e
      Rails.logger.warn("[Stops::ConditionEvaluator] compliance_violation check failed: #{e.class} #{e.message}")
      false
    end

    def stop_key(kind:, detail:)
      "stop:#{@scope_level}:#{@service_id || 'all'}:#{kind}:#{detail}:#{Date.current.iso8601}"
    end
  end
end
