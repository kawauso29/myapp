# LedgerV2::EvaluateImprovement — Ticket 解決後に元の指標が改善したかを追跡するサービス。
#
# 責務:
# - status: resolved かつ metric_name を持つ Ticket を対象にする
# - Ticket 解決（updated_at）以降の最新 MetricSnapshot と閾値を比較する
# - improvement_detected / improvement_not_detected Event を記録する
# - 同一 Ticket につき 1 回のみ評価する（payload_json->>'ticket_id' で冪等判定）
#
# やらないこと:
# - Ticket を自動 close / reopen しない
# - FeatureFlag / StopCondition / 戦略・設定の変更をしない
# - 自動マージ・自動デプロイをしない
#
# 呼び出し例:
#   RunExecutor.call(:evaluate_improvement, trigger_type: :schedule)
#   RunExecutor.call(:evaluate_improvement, trigger_type: :manual, dry_run: true)
#
# 設計の正本: ledger_v2_detailed_design.txt §「LedgerV2::EvaluateImprovement」
module LedgerV2
  class EvaluateImprovement
    # metric_name → {threshold_key:, direction: :min/:max}
    # direction: :min = 指標が threshold 以上なら正常（below_minimum 異常の解消を判定）
    #            :max = 指標が threshold 以下なら正常（exceeded_threshold 異常の解消を判定）
    # DetectMetricAnomalies::THRESHOLDS のキーを参照して閾値値を取得する。
    METRIC_CONFIG = {
      "ai_sns_posts_count"                => { threshold_key: :ai_sns_posts_count_min,                direction: :min },
      "ai_sns_dm_count"                   => { threshold_key: :ai_sns_dm_count_min,                  direction: :min },
      "error_count"                       => { threshold_key: :error_count_max,                       direction: :max },
      "ci_success_rate"                   => { threshold_key: :ci_success_rate_min,                   direction: :min },
      "open_ticket_count"                 => { threshold_key: :open_ticket_count_max,                 direction: :max },
      "artifact_pending_count"            => { threshold_key: :artifact_pending_count_max,            direction: :max },
      "customer_feedback_escalated_count" => { threshold_key: :customer_feedback_escalated_count_max, direction: :max },
      "knowledge_incident_count"          => { threshold_key: :knowledge_incident_count_max,          direction: :max },
      "knowledge_stale_draft_count"       => { threshold_key: :knowledge_stale_draft_count_max,       direction: :max },
      "experiment_expired_count"          => { threshold_key: :experiment_expired_count_max,          direction: :max }
    }.freeze

    # @param run     [LedgerV2::Run]  RunExecutor が生成した Run
    # @param dry_run [Boolean]        true なら DB 書き込みをスキップ
    # @return [LedgerV2::RunExecutor::RunnerResult]
    def self.call(run:, dry_run: false, **)
      new(run: run, dry_run: dry_run).call
    end

    def initialize(run:, dry_run:)
      @run     = run
      @dry_run = dry_run
    end

    def call
      evaluated_count                = 0
      improvement_detected_count     = 0
      improvement_not_detected_count = 0

      # metric_name を持つ resolved Ticket をすべて対象にする。
      # already_evaluated? で冪等を保証するため、resolved 日時で絞らない。
      Ticket.status_resolved.where.not(metric_name: nil).find_each do |ticket|
        config = METRIC_CONFIG[ticket.metric_name]
        next unless config
        next if already_evaluated?(ticket)

        # Ticket が resolved になった（updated_at）以降の最新 MetricSnapshot を取得する。
        # updated_at は resolved 操作の時刻の近似として使う。
        latest_snap = MetricSnapshot
                        .where(metric_name: ticket.metric_name, period: :daily)
                        .where("measured_at > ?", ticket.updated_at)
                        .order(measured_at: :desc)
                        .first

        # 解決後に MetricSnapshot がまだ存在しない場合は評価を保留する。
        next unless latest_snap

        threshold = DetectMetricAnomalies::THRESHOLDS[config[:threshold_key]]
        improved  = improved?(latest_snap.value, threshold, config[:direction])

        if @dry_run
          evaluated_count += 1
        else
          record_event(ticket: ticket, snapshot: latest_snap, improved: improved,
                       threshold: threshold, direction: config[:direction])
          evaluated_count += 1
          if improved
            improvement_detected_count += 1
          else
            improvement_not_detected_count += 1
          end
        end
      end

      RunExecutor::RunnerResult.new(
        created_event_count: improvement_detected_count + improvement_not_detected_count
      )
    end

    private

    # 同一 Ticket に対して評価 Event がすでに存在するかを確認する（冪等ガード）。
    def already_evaluated?(ticket)
      Event.where(event_type: %w[improvement_detected improvement_not_detected])
           .where("payload_json->>'ticket_id' = ?", ticket.id.to_s)
           .exists?
    end

    # 指標が「改善した」かを判定する。
    # :min の場合: 指標が閾値以上なら改善（below_minimum 異常が解消）
    # :max の場合: 指標が閾値以下なら改善（exceeded_threshold 異常が解消）
    def improved?(value, threshold, direction)
      case direction
      when :min then value.to_f >= threshold.to_f
      when :max then value.to_f <= threshold.to_f
      end
    end

    def record_event(ticket:, snapshot:, improved:, threshold:, direction:)
      Event.create!(
        run:          @run,
        event_type:   improved ? "improvement_detected" : "improvement_not_detected",
        severity:     :info,
        occurred_at:  Time.current,
        message:      "#{ticket.metric_name} = #{snapshot.value} (threshold: #{threshold}, direction: #{direction})",
        payload_json: {
          "ticket_id"     => ticket.id,
          "metric_name"   => ticket.metric_name,
          "current_value" => snapshot.value.to_f,
          "threshold"     => threshold,
          "direction"     => direction.to_s,
          "snapshot_id"   => snapshot.id,
          "improved"      => improved
        },
        subject_type: "LedgerV2::Ticket",
        subject_id:   ticket.id
      )
    end
  end
end
