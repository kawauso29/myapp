module Stops
  # Phase 33 / 補強7: ルール駆動の自動停止を評価し、必要なら StopLedger を起票する。
  #
  # 現時点のルール:
  #   - KPI grade が critical になったら kpi_breach で停止
  #   - OperatorOverrideLedger で halt_* が active なら manual_escalation として記録（冪等）
  #   - 当月 CostLedger 合計が閾値（`COST_RUNAWAY_MONTHLY_JPY` 環境変数 or 既定値）を
  #     超えたら cost_runaway で停止
  # 個別ルールは段階的に追加する。
  class ConditionEvaluator
    Result = Struct.new(:created, :existing, keyword_init: true)

    # Phase 33 / §18: cost_runaway の既定月間閾値。`COST_RUNAWAY_MONTHLY_JPY` で上書き可能。
    # サービス単位 (scope_level: :service) の月間コストがこの値を超えたら停止する。
    DEFAULT_COST_RUNAWAY_MONTHLY_JPY = 100_000

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
    # KillSwitchGuard が halt 中のジョブ実行を止めるのとは別軸で、「停止事実」を StopLedger に
    # も残しておくことで監査証跡と Admin Viewer の可視性を揃える。
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
    # scope_level が :service のときのみ評価（company/portfolio での集計は Phase 41 以降で拡張）。
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
      if @scope_level == :service
        kpis = kpis.where(service_id: @service_id)
      end
      kpis
    end

    def stop_key(kind:, detail:)
      "stop:#{@scope_level}:#{@service_id || 'all'}:#{kind}:#{detail}:#{Date.current.iso8601}"
    end
  end
end
