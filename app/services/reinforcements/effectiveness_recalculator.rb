module Reinforcements
  # Phase D (自律成長ループ): 完了した improvement チケットに `effectiveness_score` を書き戻す。
  # 補強10 の学習ループ (`EffectivenessEvaluator.evaluate`) が読み取るためのデータを供給する。
  #
  # スコア算出ロジック（最小実装）:
  #   - `linked_kpis` から `"kpi:..."` 形式のキーを再帰的に抽出
  #   - 各キーの KpiLedger について `current_value.value / target_value.value` を 0..1 に clamp
  #   - target 未設定・value 欠落の KPI はスキップ
  #   - 使えた KPI 数だけ平均し、ticket に書き戻す（sample_size も記録）
  #
  # 対象: status=completed の improvement チケットで `effectiveness_score IS NULL` のもののみ。
  # 冪等: 書き込み後は以降スキップされる。
  class EffectivenessRecalculator
    KPI_KEY_REGEX = /\Akpi:/.freeze

    def self.call
      new.call
    end

    def call
      processed = 0
      updated = 0
      skipped_no_kpi = 0
      skipped_no_target = 0

      candidates.find_each do |ticket|
        processed += 1
        kpi_keys = extract_kpi_keys(ticket.linked_kpis)
        if kpi_keys.empty?
          skipped_no_kpi += 1
          next
        end

        scores = collect_scores(kpi_keys)
        if scores.empty?
          skipped_no_target += 1
          next
        end

        avg = (scores.sum / scores.size.to_f).round(4)
        ticket.update_columns(
          effectiveness_score: avg,
          effectiveness_sample_size: scores.size,
          effectiveness_updated_at: Time.current,
          updated_at: Time.current
        )
        updated += 1
      end

      {
        processed: processed,
        updated: updated,
        skipped_no_kpi: skipped_no_kpi,
        skipped_no_target: skipped_no_target
      }
    end

    private

    def candidates
      TicketLedger
        .ticket_type_improvement
        .where(status: TicketLedger.statuses[:completed])
        .where(effectiveness_score: nil)
    end

    # linked_kpis は配列・ハッシュが混在するため、文字列を再帰的に集めて "kpi:..." だけ拾う。
    def extract_kpi_keys(linked)
      strings = []
      walk = ->(node) do
        case node
        when String
          strings << node if node =~ KPI_KEY_REGEX
        when Array
          node.each { |n| walk.call(n) }
        when Hash
          node.each_value { |n| walk.call(n) }
        end
      end
      walk.call(linked)
      strings.uniq
    end

    def collect_scores(kpi_keys)
      scores = []
      KpiLedger.where(kpi_key: kpi_keys).find_each do |kpi|
        actual = numeric_from(kpi.current_value)
        target = numeric_from(kpi.target_value)
        next if actual.nil? || target.nil? || target.zero?

        ratio = (actual.to_f / target.to_f)
        scores << ratio.clamp(0.0, 1.0)
      end
      scores
    end

    def numeric_from(json_value)
      return nil if json_value.blank?
      return json_value.to_f if json_value.is_a?(Numeric)

      val = json_value.is_a?(Hash) ? (json_value["value"] || json_value[:value]) : nil
      val.is_a?(Numeric) ? val.to_f : (Float(val) rescue nil)
    end
  end
end
