module Reinforcements
  # Phase A (自律成長ループ): Admin::KpiService.weekly_metrics を KpiLedger.current_value に
  # 自動投入する。R4 / ImprovementDetector / Reinforcements::Planner の入力データを供給する。
  #
  # current_value の JSON 形状は ExperimentAutoDecider#kpi_met? に合わせて
  # `{ "value" => Numeric, "recorded_at" => iso8601, "source" => "kpi_auto_collector", "unit" => String }`
  # で統一する。
  class KpiAutoCollector
    SOURCE = "kpi_auto_collector".freeze

    # 既存シード KPI に対する `Admin::KpiService.weekly_metrics` への単純マッピング。
    # 値が取れない KPI はスキップして unmapped に計上する（壊さない運用）。
    MAPPINGS = {
      "kpi:ai_sns_wau" => {
        path: %i[users wau],
        unit: "users"
      },
      "kpi:ai_sns_retention_7d" => {
        path: %i[users retention_30d_pct],
        unit: "percent",
        note: "retention_30d_pct を 7d 代理指標として暫定利用"
      },
      "kpi:ai_sns_paid_conversion" => {
        compute: ->(m) {
          total = m.dig(:users, :total).to_f
          paid  = m.dig(:users, :paid).to_f
          total.positive? ? ((paid / total) * 100).round(2) : nil
        },
        unit: "percent"
      },
      "kpi:service_health" => {
        # 暫定: week 内 posts>0 かつ engagement>0 なら 1.0、片方欠落で 0.5、全部 0 で 0.0
        compute: ->(m) {
          posts = m.dig(:posts, :this_week).to_i
          likes = m.dig(:engagement, :user_likes_this_week).to_i
          score = 0.0
          score += 0.5 if posts.positive?
          score += 0.5 if likes.positive?
          score
        },
        unit: "score_0_1"
      },
      # Phase 42 / UI伴走管理: UI 画面稼働率。
      # WAU が存在すれば UI がアクティブとみなす代理指標（binary: 100% or 0%）。
      # 実際の画面到達率ではなく「UI利用有無」を示す指標のため、
      # 名称に "_activity_proxy" を含む KPI key を将来追加して差し替えることを推奨。
      # ※ この値を単独で意思決定に使用しないこと（補助指標として扱う）。
      "kpi:ai_sns_ui_screen_coverage" => {
        compute: ->(m) {
          wau = m.dig(:users, :wau).to_i
          wau.positive? ? 100.0 : 0.0
        },
        unit: "percent"
      },
      # Phase 42 / UI伴走管理: UI クラッシュ率。
      # フロントエンド計装（Sentry 等）が未実装のため現時点は nil を返しスキップする。
      # 将来的にはエラー率 API から自動収集に切り替える。
      "kpi:ai_sns_ui_crash_rate" => {
        compute: ->(_m) { nil },
        unit: "percent",
        note: "frontend crash instrumentation not yet implemented"
      }
    }.freeze

    def self.call
      new.call
    end

    def call
      metrics = Admin::KpiService.weekly_metrics.deep_symbolize_keys
      return { updated: 0, skipped: 0, error: metrics[:error] } if metrics[:error].present?

      updated = []
      skipped = []
      recorded_at = Time.current.iso8601

      MAPPINGS.each do |kpi_key, spec|
        kpi = KpiLedger.find_by(kpi_key: kpi_key)
        next unless kpi

        value = extract_value(metrics, spec)
        if value.nil?
          skipped << kpi_key
          next
        end

        payload = {
          "value" => value,
          "recorded_at" => recorded_at,
          "source" => SOURCE,
          "unit" => spec[:unit]
        }
        payload["note"] = spec[:note] if spec[:note].present?

        kpi.update!(current_value: payload)
        updated << kpi_key
      end

      {
        updated: updated.size,
        skipped: skipped.size,
        updated_keys: updated,
        skipped_keys: skipped
      }
    rescue => e
      Rails.logger.error("[KpiAutoCollector] failed: #{e.class} #{e.message}")
      { updated: 0, skipped: 0, error: e.message }
    end

    private

    def extract_value(metrics, spec)
      if spec[:compute].respond_to?(:call)
        spec[:compute].call(metrics)
      else
        metrics.dig(*spec[:path])
      end
    end
  end
end
