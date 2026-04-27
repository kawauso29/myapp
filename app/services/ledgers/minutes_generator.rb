module Ledgers
  # 各 Runner が会議終了時に呼び出し、人間が読める議事録を生成する。
  # MeetingLedger#minutes（jsonb）に保存され、管理画面の show ページで表示される。
  #
  # 構造:
  #   purpose      : 会議の目的（1行テキスト）
  #   agenda       : 議題一覧（Array<String>）
  #   discussion_log: 議論ログ（Array<{speaker:, topic:, content:}>）
  #   outcome      : 結果サマリ（1〜3行テキスト）
  #   generated_at : 生成日時（ISO8601）
  class MinutesGenerator
    # weekly の decisions で「保留・スキップ」扱いにする result 値の一覧
    NON_APPROVED_RESULTS = %w[
      held_for_missing_kpis
      held_for_missing_kpi_definition
      held_for_active_stop
      held_for_lane_capacity_exceeded
      held_for_callback_blocked
      skipped_duplicate_default
    ].freeze

    def self.generate(purpose:, agenda:, discussion_log:, outcome:)
      {
        "purpose"       => purpose.to_s,
        "agenda"        => Array(agenda).map(&:to_s),
        "discussion_log" => Array(discussion_log).map { |entry| entry.transform_keys(&:to_s) },
        "outcome"       => outcome.to_s,
        "generated_at"  => Time.current.iso8601
      }
    end

    # ---------- ランナー別ファクトリメソッド ----------

    def self.for_daily(service_id:, kpi_snapshot:, anomalies:, carry_over:)
      kpi_count     = kpi_snapshot.size
      anomaly_count = anomalies.size

      agenda = [ "KPIスナップショット収集（#{kpi_count}件）", "異常検知" ]
      agenda << "前回からの引き継ぎ（#{carry_over.size}件）" if carry_over.any?

      log = []
      log << {
        speaker: "system",
        topic:   "KPI監視",
        content: "#{kpi_count}件のKPIをスキャンしました。" +
                 (anomaly_count > 0 ? "#{anomaly_count}件の異常（critical）を検知。" : "異常なし。")
      }
      anomalies.each do |a|
        a_s     = a.transform_keys(&:to_s)
        kpi_key = a_s["kpi_key"]
        grade   = a_s["grade"]
        val     = a_s["current_value"]
        log << {
          speaker: "system",
          topic:   "異常検知",
          content: "KPI #{kpi_key} が #{grade} グレードです。" +
                   (val.present? ? "（現在値: #{val.is_a?(Hash) ? val.to_json : val}）" : "")
        }
      end
      if carry_over.any?
        log << {
          speaker: "system",
          topic:   "引き継ぎ",
          content: "前回の hold_items #{carry_over.size}件を引き継ぎます。"
        }
      end

      outcome =
        if anomaly_count > 0
          "#{anomaly_count}件の異常を hold_items に記録しました。次週の weekly 会議で審査します。"
        else
          "#{kpi_count}件のKPIをすべて正常確認しました。異常なし。"
        end

      generate(
        purpose:        "#{service_id} 日次自動監視（KPI収集・異常検知）",
        agenda:         agenda,
        discussion_log: log,
        outcome:        outcome
      )
    end

    def self.for_weekly(service_id:, decisions:, hold_items:, improvements:, escalations:)
      approved = decisions.count { |d| !NON_APPROVED_RESULTS.include?(d.transform_keys(&:to_s)["result"].to_s) }
      held     = hold_items.size
      detected = improvements&.fetch(:detected, 0).to_i
      resolved = improvements&.fetch(:resolved, 0).to_i

      agenda = []
      agenda << "チケット審議（#{decisions.size}件）" if decisions.any?
      agenda << "改善検知・解消レビュー"
      agenda << "AI SNS計画 approved 昇格確認" if decisions.any? { |d| d.transform_keys(&:to_s)["result"].to_s == "planned" }

      log = []
      decisions.each do |raw_d|
        d      = raw_d.transform_keys(&:to_s)
        title  = d["title"]
        result = d["result"].to_s
        tid    = d["ticket_id"]
        content =
          case result
          when "approved"
            "チケット「#{title}」を承認しました。（チケットID: #{tid}）"
          when "waiting_review"
            "チケット「#{title}」は監査レビュー待ちとなりました。（チケットID: #{tid}）"
          when "planned"
            "AI SNS計画チケット「#{title}」を planned に昇格しました。（チケットID: #{tid}）"
          when "held_for_missing_kpis"
            "チケット「#{title}」はリンクKPIが未設定のため保留にしました。"
          when "held_for_missing_kpi_definition"
            "チケット「#{title}」はKPI定義が存在しないため保留にしました。"
          when "held_for_active_stop"
            "チケット「#{title}」はサービス停止中のため保留にしました。"
          when "held_for_lane_capacity_exceeded"
            "チケット「#{title}」はレーン上限超過のため保留にしました。"
          when "skipped_duplicate_default"
            "チケット「#{title}」は既存のデフォルトチケットと重複するためスキップしました。"
          else
            "チケット「#{title}」の処理結果: #{result}"
          end
        log << { speaker: "business_owner（議長）", topic: "チケット審議", content: content }
      end

      if detected > 0 || resolved > 0
        log << {
          speaker: "system（自動検知）",
          topic:   "改善検知・解消",
          content: "改善検知: #{detected}件、解消: #{resolved}件。"
        }
        details = Array(improvements&.fetch(:details, []))
        details.first(5).each do |det|
          det_s = det.is_a?(Hash) ? det.transform_keys(&:to_s) : {}
          op    = det_s["operation"] || det_s["rule"] || det_s["action"]
          ttl   = det_s["title"]
          log << { speaker: "system（自動検知）", topic: "改善詳細", content: "#{op}: #{ttl}" } if ttl.present?
        end
      end

      escalations.each do |raw_esc|
        esc = raw_esc.transform_keys(&:to_s)
        log << {
          speaker: "audit（監査）",
          topic:   "監査エスカレーション",
          content: "チケット ##{esc["ticket_id"]} を #{esc["escalation_to"]} にエスカレーションしました。"
        }
      end

      outcome_parts = []
      outcome_parts << "承認 #{approved}件" if approved > 0
      outcome_parts << "保留 #{held}件（次週に引き継ぎ）" if held > 0
      outcome_parts << "改善検知 #{detected}件、解消 #{resolved}件" if detected > 0 || resolved > 0
      outcome = outcome_parts.any? ? outcome_parts.join("、") + "。" : "処理対象なし。"

      generate(
        purpose:        "#{service_id} 週次部門会議（運営チェックポイント）",
        agenda:         agenda,
        discussion_log: log,
        outcome:        outcome
      )
    end

    def self.for_monthly(decisions:, resolved:, overdue_marked:, escalated:)
      agenda = []
      agenda << "待機中チケットの審査・承認（#{decisions.size}件）" if decisions.any?
      agenda << "改善解消・エスカレーション処理"

      log = []
      decisions.each do |raw_d|
        d          = raw_d.transform_keys(&:to_s)
        tid        = d["ticket_id"]
        resolution = d["resolution"].to_s
        label =
          case resolution
          when "approved"   then "承認"
          when "draft"      then "ドラフト（週次へ差し戻し）"
          when "cancelled"  then "キャンセル"
          else resolution
          end
        log << { speaker: "ceo（議長）", topic: "チケット審議", content: "チケット ##{tid} を #{label} としました。" }
      end
      if resolved > 0 || overdue_marked > 0 || escalated > 0
        log << {
          speaker: "system（自動処理）",
          topic:   "改善・エスカレーション",
          content: "解消 #{resolved}件、期限超過マーク #{overdue_marked}件、四半期エスカレーション #{escalated}件。"
        }
      end

      approved_count = decisions.count { |d| d.transform_keys(&:to_s)["resolution"].to_s == "approved" }
      outcome_parts  = []
      outcome_parts << "承認 #{approved_count}件" if decisions.any?
      outcome_parts << "解消 #{resolved}件" if resolved > 0
      outcome_parts << "期限超過マーク #{overdue_marked}件" if overdue_marked > 0
      outcome = outcome_parts.any? ? outcome_parts.join("、") + "。" : "処理対象なし。"

      generate(
        purpose:        "月次運営会議（待機中チケット審査・改善処置）",
        agenda:         agenda,
        discussion_log: log,
        outcome:        outcome
      )
    end

    def self.for_quarterly(metrics:, quarter:, year:)
      agenda = [
        "四半期 KPI 達成状況の総括",
        "チケット完了率・遅延率のレビュー",
        "次四半期への提言"
      ]

      total    = metrics[:meetings_held].to_i
      t_total  = metrics[:tickets_total].to_i
      approved = metrics[:tickets_approved].to_i
      overdue  = metrics[:tickets_overdue].to_i

      log = [
        { speaker: "ceo（議長）", topic: "四半期総括",
          content: "Q#{quarter} #{year}: 会議 #{total}回を実施しました。" },
        { speaker: "executive_planning（役員企画）", topic: "チケット集計",
          content: "チケット総数 #{t_total}件のうち承認 #{approved}件、期限超過 #{overdue}件。" }
      ]

      outcome = "Q#{quarter} #{year} 四半期サマリーチケットを発行しました。" \
                "会議 #{total}回、チケット #{t_total}件（承認 #{approved}件、遅延 #{overdue}件）。"

      generate(
        purpose:        "四半期レビュー（Q#{quarter} #{year}）",
        agenda:         agenda,
        discussion_log: log,
        outcome:        outcome
      )
    end

    def self.for_ui_check(service_id:, kpi_snapshot:, anomalies:)
      kpi_count     = kpi_snapshot.size
      anomaly_count = anomalies.size

      agenda = [ "UI固有KPI確認（#{kpi_count}件）" ]
      agenda << "異常検知（#{anomaly_count}件）" if anomaly_count > 0

      log = []
      log << {
        speaker: "dev（議長）",
        topic:   "UI KPI確認",
        content: "#{kpi_count}件のUI KPIをスキャンしました。" +
                 (anomaly_count > 0 ? "#{anomaly_count}件の異常（critical）を検知。" : "異常なし。")
      }
      anomalies.each do |a|
        anomaly_data = a.transform_keys(&:to_s)
        kpi_key = anomaly_data["kpi_key"]
        grade   = anomaly_data["grade"]
        val     = anomaly_data["current_value"]
        log << {
          speaker: "dev（議長）",
          topic:   "異常検知",
          content: "KPI #{kpi_key} が #{grade} グレードです。" +
                   (val.present? ? "（現在値: #{val.is_a?(Hash) ? val.to_json : val}）" : "")
        }
      end

      outcome =
        if anomaly_count > 0
          "#{anomaly_count}件のUI KPI異常を hold_items に記録しました。次週の weekly 会議で審査します。"
        else
          "#{kpi_count}件のUI KPIをすべて正常確認しました。stale_ui_check 解消。"
        end

      generate(
        purpose:        "#{service_id} UI チェック（画面稼働率・クラッシュ率・WAU 確認）",
        agenda:         agenda,
        discussion_log: log,
        outcome:        outcome
      )
    end

    def self.for_annual(metrics:, year:)
      agenda = [
        "年間 KPI 総括",
        "四半期レビュー横断分析",
        "翌年度計画の承認"
      ]

      log = [
        { speaker: "ceo（議長）", topic: "年間総括",
          content: "FY#{year}: 会議 #{metrics[:total_meetings].to_i}回を実施しました。" },
        { speaker: "executive_planning（役員企画）", topic: "チケット集計",
          content: "チケット総数 #{metrics[:tickets_total].to_i}件のうち承認 #{metrics[:tickets_approved].to_i}件。" \
                   "期限超過率 #{metrics[:overdue_rate]}。" },
        { speaker: "cto（CTO）", topic: "四半期レビュー横断",
          content: "四半期レビュー #{metrics[:quarterly_reviews].to_i}回を総括しました。" }
      ]

      outcome = "FY#{year} 年次計画チケットを発行しました。" \
                "チケット #{metrics[:tickets_total].to_i}件（期限超過率 #{metrics[:overdue_rate]}）。"

      generate(
        purpose:        "年次計画会議（FY#{year}）",
        agenda:         agenda,
        discussion_log: log,
        outcome:        outcome
      )
    end
  end
end
