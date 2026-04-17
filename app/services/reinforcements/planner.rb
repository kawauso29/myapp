module Reinforcements
  # Phase B (自律成長ループ): KPI の actual / target 乖離から improvement ticket を
  # 自動起票する「発案エージェント」の最小版（ルールベース / LLM なし）。
  #
  # ルール:
  #   1. KpiLedger の current_value / target_value が両方 present で、actual < target * UNDERPERFORM_RATIO
  #   2. 同じ `improvement_pattern_key` の open チケットが既に存在するなら skip
  #   3. 補強10 の EffectivenessEvaluator で low_effectiveness と判定されたパターンは skip
  #      （過去の成績が悪いパターンを機械的に繰り返さない）
  #   4. 1 回の実行での起票上限を MAX_PER_RUN 件に抑える（改善案の氾濫防止）
  #
  # 将来: LLM による仮説生成に差し替える際は `propose_for_kpi(kpi)` の中身だけ入れ替える。
  class Planner
    UNDERPERFORM_RATIO = 0.8 # actual が target の 80% 未満で underperform
    MAX_PER_RUN = 3
    DEFAULT_DUE_DAYS = 14
    PATTERN_PREFIX = "planner:kpi_underperform".freeze

    def self.call
      new.call
    end

    def call
      created = []
      skipped = []

      underperforming_kpis.each do |kpi|
        break if created.size >= MAX_PER_RUN

        pattern_key = pattern_key_for(kpi)

        if duplicate_open?(pattern_key)
          skipped << { kpi_key: kpi.kpi_key, reason: "duplicate_open" }
          next
        end

        if low_effectiveness_pattern?(pattern_key)
          skipped << { kpi_key: kpi.kpi_key, reason: "low_effectiveness_pattern" }
          next
        end

        ticket = create_improvement_ticket!(kpi: kpi, pattern_key: pattern_key)
        created << { kpi_key: kpi.kpi_key, ticket_id: ticket.id, pattern_key: pattern_key }
      end

      { created: created.size, skipped: skipped.size, details: { created: created, skipped: skipped } }
    rescue => e
      Rails.logger.error("[Reinforcements::Planner] failed: #{e.class} #{e.message}")
      { created: 0, skipped: 0, error: e.message }
    end

    private

    def underperforming_kpis
      KpiLedger.status_active.select do |kpi|
        actual = numeric_from(kpi.current_value)
        target = numeric_from(kpi.target_value)
        actual.present? && target.present? && target.positive? && actual < (target * UNDERPERFORM_RATIO)
      end
    end

    def pattern_key_for(kpi)
      "#{PATTERN_PREFIX}:#{kpi.kpi_key}"
    end

    def duplicate_open?(pattern_key)
      TicketLedger
        .ticket_type_improvement
        .where(improvement_pattern_key: pattern_key)
        .where.not(status: [ TicketLedger.statuses[:completed], TicketLedger.statuses[:cancelled] ])
        .exists?
    end

    def low_effectiveness_pattern?(pattern_key)
      result = EffectivenessEvaluator.evaluate(pattern_key)
      result.recommend_alternative?
    rescue => e
      Rails.logger.warn("[Planner] effectiveness check failed for #{pattern_key}: #{e.message}")
      false
    end

    def create_improvement_ticket!(kpi:, pattern_key:)
      actual = numeric_from(kpi.current_value)
      target = numeric_from(kpi.target_value)
      gap_pct = target.positive? ? (((target - actual) / target) * 100).round(1) : nil

      TicketLedger.create!(
        ticket_type: :improvement,
        title: "Planner proposal: improve #{kpi.kpi_key} (actual #{actual} vs target #{target}#{gap_pct ? ", -#{gap_pct}%" : ''})",
        scope_level: kpi.scope_level_service? ? :service : :company,
        service_id: kpi.service_id,
        source_meeting_type: :weekly,
        improvement_pattern_key: pattern_key,
        linked_kpis: [ kpi.kpi_key ],
        linked_artifacts: [],
        priority: :medium,
        status: :draft,
        assignee: "reinforcements_planner",
        due_date: Date.current + DEFAULT_DUE_DAYS.days,
        due_cycle: :weekly,
        risk_level: :low
      )
    end

    def numeric_from(json_value)
      return nil if json_value.blank?
      return json_value.to_f if json_value.is_a?(Numeric)

      val = json_value.is_a?(Hash) ? (json_value["value"] || json_value[:value]) : nil
      return val.to_f if val.is_a?(Numeric)
      Float(val) rescue nil
    end
  end
end
