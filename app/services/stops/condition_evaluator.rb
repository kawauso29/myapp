module Stops
  # Phase 33 / 補強7: ルール駆動の自動停止を評価し、必要なら StopLedger を起票する。
  #
  # 現時点のルール:
  #   - KPI grade が critical になったら kpi_breach で停止
  #   - OperatorOverrideLedger で halt_* が active なら manual_escalation として記録（冪等）
  # 個別ルールは段階的に追加する。
  class ConditionEvaluator
    Result = Struct.new(:created, :existing, keyword_init: true)

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

      critical_kpis.each do |kpi|
        key = stop_key(kind: "kpi_critical", detail: kpi.kpi_key)
        next if existing.any? { |s| s.idempotency_key == key }

        created << StopLedger.create!(
          trigger_type: :kpi_breach,
          trigger_detail: "KPI #{kpi.kpi_key} grade=critical",
          scope_level: @scope_level,
          service_id: @service_id,
          status: :active,
          started_at: Time.current,
          evidence: { kpi_key: kpi.kpi_key, current_value: kpi.current_value, thresholds: kpi.thresholds, grade: kpi.grade },
          idempotency_key: key
        )
      end

      Result.new(created: created, existing: existing)
    end

    private

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
