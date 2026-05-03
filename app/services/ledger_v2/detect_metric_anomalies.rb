# LedgerV2::DetectMetricAnomalies — MetricSnapshot から異常を検出する。
#
# 責務:
# - MetricSnapshot の値を閾値ルールと比較して異常候補を返す
# - 副作用（Ticket 作成・Event 記録）は行わない
# - Ticket 作成は LedgerV2::OpenTicket（DailyRunner から呼び出す）に任せる
#
# 重要ルール:
# - 初期から高度な AI 判定をしない（閾値・ルールベースから始める）
# - 判定理由は Anomaly#payload_json に残す
# - 異常検知だけで副作用を起こさない
# 設計の正本: ledger_v2_detailed_design.txt §「LedgerV2::DetectMetricAnomalies」
module LedgerV2
  module DetectMetricAnomalies
    # 異常検知の結果を表す値オブジェクト。
    # DailyRunner が OpenTicket.call の引数として使う。
    Anomaly = Struct.new(
      :canonical_key,
      :title,
      :severity,
      :description,
      :metric_name,
      :anomaly_type,
      :period_bucket,
      :payload_json,
      keyword_init: true
    )

    # 閾値定義（運用中に調整する）
    THRESHOLDS = {
      ai_sns_posts_count_min:                  5,    # 1 日の最低投稿数
      ai_sns_dm_count_min:                     1,    # DM 数の最低値
      error_count_max:                         10,   # エラー件数の上限
      ci_success_rate_min:                     0.8,  # CI 成功率の下限（80%）
      open_ticket_count_max:                   20,   # open Ticket の上限
      artifact_pending_count_max:              5,    # pending Artifact の上限
      customer_feedback_escalated_count_max:   3,    # エスカレート済みフィードバックの上限（period 内）
      knowledge_incident_count_max:            3,    # period 内 incident エントリの上限
      knowledge_stale_draft_count_max:         5     # stale draft（7日以上放置）の上限
    }.freeze

    # @param snapshots [Array<LedgerV2::MetricSnapshot>]  検査対象のスナップショット群
    # @return [Array<Anomaly>]  検知された異常のリスト（異常なし時は空の配列）
    def self.call(snapshots:)
      snapshots.filter_map { |snap| check_snapshot(snap) }
    end

    # @api private
    def self.check_snapshot(snap)
      case snap.metric_name
      when "ai_sns_posts_count"
        check_min(snap, THRESHOLDS[:ai_sns_posts_count_min],
                  anomaly_type: "below_minimum",
                  title:        "AI-SNS 投稿数が最低値を下回っています",
                  severity:     :medium)
      when "ai_sns_dm_count"
        check_min(snap, THRESHOLDS[:ai_sns_dm_count_min],
                  anomaly_type: "below_minimum",
                  title:        "AI-SNS DM 数が極端に低下しています",
                  severity:     :low)
      when "error_count"
        check_max(snap, THRESHOLDS[:error_count_max],
                  anomaly_type: "exceeded_threshold",
                  title:        "エラー件数が閾値を超えています",
                  severity:     :high)
      when "ci_success_rate"
        check_min(snap, THRESHOLDS[:ci_success_rate_min],
                  anomaly_type: "below_minimum",
                  title:        "CI 成功率が閾値を下回っています",
                  severity:     :high)
      when "open_ticket_count"
        check_max(snap, THRESHOLDS[:open_ticket_count_max],
                  anomaly_type: "exceeded_threshold",
                  title:        "open Ticket 数が上限を超えています",
                  severity:     :medium)
      when "artifact_pending_count"
        check_max(snap, THRESHOLDS[:artifact_pending_count_max],
                  anomaly_type: "exceeded_threshold",
                  title:        "pending Artifact 数が上限を超えています",
                  severity:     :medium)
      when "customer_feedback_escalated_count"
        check_max(snap, THRESHOLDS[:customer_feedback_escalated_count_max],
                  anomaly_type: "exceeded_threshold",
                  title:        "エスカレート済み顧客フィードバックが上限を超えています",
                  severity:     :high)
      when "knowledge_incident_count"
        check_max(snap, THRESHOLDS[:knowledge_incident_count_max],
                  anomaly_type: "exceeded_threshold",
                  title:        "incident 種別の知識エントリが上限を超えています",
                  severity:     :high)
      when "knowledge_stale_draft_count"
        check_max(snap, THRESHOLDS[:knowledge_stale_draft_count_max],
                  anomaly_type: "exceeded_threshold",
                  title:        "放置中の draft 知識エントリが上限を超えています",
                  severity:     :medium)
      end
    end
    private_class_method :check_snapshot

    # value < threshold のとき Anomaly を返す（正常なら nil）
    def self.check_min(snap, threshold, title:, anomaly_type:, severity:)
      return nil unless snap.value < threshold

      build_anomaly(snap, threshold, title: title, anomaly_type: anomaly_type, severity: severity,
                                     direction: "below")
    end
    private_class_method :check_min

    # value > threshold のとき Anomaly を返す（正常なら nil）
    def self.check_max(snap, threshold, title:, anomaly_type:, severity:)
      return nil unless snap.value > threshold

      build_anomaly(snap, threshold, title: title, anomaly_type: anomaly_type, severity: severity,
                                     direction: "above")
    end
    private_class_method :check_max

    # Anomaly 値オブジェクトを組み立てる
    def self.build_anomaly(snap, threshold, title:, anomaly_type:, severity:, direction:)
      period_bucket = "#{snap.period}:#{snap.measured_at.strftime('%Y-%m-%d')}"
      description = direction == "below" \
        ? "#{snap.metric_name} = #{snap.value} (閾値: #{threshold} 以上が必要)" \
        : "#{snap.metric_name} = #{snap.value} (閾値: #{threshold} 以下が必要)"

      Anomaly.new(
        canonical_key: "ledger_v2:#{snap.metric_name}:#{anomaly_type}:#{period_bucket}",
        title:         title,
        severity:      severity,
        description:   description,
        metric_name:   snap.metric_name,
        anomaly_type:  anomaly_type,
        period_bucket: period_bucket,
        payload_json:  {
          "value"     => snap.value.to_f,
          "threshold" => threshold,
          "direction" => direction,
          "unit"      => snap.unit
        }
      )
    end
    private_class_method :build_anomaly
  end
end
