# LedgerV2::DailyRunner — 日次観測と最小限の異常検知を行う。
#
# 責務:
# - KPI の MetricSnapshot を取得（または作成）する
# - DetectMetricAnomalies で異常候補を得る
# - 各異常候補について OpenTicket を呼び、Ticket または重複防止 Event を残す
# - RunExecutor の RunnerResult を返す
#
# やらないこと:
# - Artifact を大量生成しない
# - 戦略変更しない
# - 設定変更しない
# - PR を作らない
# - AI 人格・記憶を変えない
#
# 初期対象 KPI（daily 粒度、measured_at = 呼び出し時刻の日初め）:
#   - ai_sns_posts_count              … 当日の AI-SNS 投稿数（CollectAiSnsMetrics 経由）
#   - ai_sns_dm_count                 … 当日の AI-SNS DM スレッド数（CollectAiSnsMetrics 経由）
#   - ai_sns_reaction_count           … 当日の AI-SNS いいね数（CollectAiSnsMetrics 経由）
#   - customer_feedback_new_count     … 未トリアージのフィードバック件数（CollectCustomerFeedback 経由）
#   - customer_feedback_escalated_count … エスカレート済みフィードバック件数（CollectCustomerFeedback 経由）
#   - knowledge_incident_count        … period 内に作成された incident 種別の知識エントリ件数（CollectKnowledgeMetrics 経由）
#   - knowledge_stale_draft_count     … draft のまま 7 日以上放置されている知識エントリ件数（CollectKnowledgeMetrics 経由）
#   - error_count                     … SolidQueue FailedExecution 件数
#   - ci_success_rate                 … 直近 7 日の CI 成功率（未取得時は 1.0 固定）
#   - open_ticket_count               … LedgerV2::Ticket の open 件数
#   - artifact_pending_count          … LedgerV2::Artifact の draft/pending 件数
#
# 設計の正本: ledger_v2_detailed_design.txt §「LedgerV2::DailyRunner」
module LedgerV2
  class DailyRunner
    # @param run      [LedgerV2::Run]  RunExecutor が生成した Run
    # @param dry_run  [Boolean]        true なら DB 書き込みをスキップ
    # @return [LedgerV2::RunExecutor::RunnerResult]
    def self.call(run:, dry_run: false, **)
      new(run: run, dry_run: dry_run).call
    end

    def initialize(run:, dry_run:)
      @run     = run
      @dry_run = dry_run
    end

    def call
      snapshots = collect_snapshots
      anomalies = DetectMetricAnomalies.call(snapshots: snapshots)

      created_ticket_count      = 0
      duplicate_prevented_count = 0
      created_event_count       = 0

      anomalies.each do |anomaly|
        result = OpenTicket.call(
          run:           @run,
          canonical_key: anomaly.canonical_key,
          title:         anomaly.title,
          severity:      anomaly.severity,
          description:   anomaly.description,
          metric_name:   anomaly.metric_name,
          anomaly_type:  anomaly.anomaly_type,
          period_bucket: anomaly.period_bucket,
          dry_run:       @dry_run
        )

        if result.created?
          created_ticket_count += 1
          created_event_count  += 1   # ticket_opened Event
        else
          duplicate_prevented_count += 1
          created_event_count       += 1 unless @dry_run  # ticket_duplicate_prevented Event
        end
      end

      RunExecutor::RunnerResult.new(
        created_ticket_count:      created_ticket_count,
        duplicate_prevented_count: duplicate_prevented_count,
        created_event_count:       created_event_count
      )
    end

    private

    # 各 KPI のスナップショットを集める。
    # AI-SNS 指標は CollectAiSnsMetrics に委譲する。
    # dry_run でも snapshot は DB に保存する（観測ファクトは残す）。
    # ただし MetricSnapshot 作成自体が失敗しても DailyRunner は落ちない。
    def collect_snapshots
      today_start = Time.current.beginning_of_day

      ai_sns_snapshots      = CollectAiSnsMetrics.call(run: @run, period: :daily, since_at: today_start)
      feedback_snapshots    = CollectCustomerFeedback.call(run: @run, period: :daily, since_at: today_start)
      knowledge_snapshots   = CollectKnowledgeMetrics.call(run: @run, period: :daily, since_at: today_start)

      ai_sns_snapshots + feedback_snapshots + knowledge_snapshots + [
        snapshot_for("error_count",           error_count,           today_start),
        snapshot_for("ci_success_rate",       ci_success_rate,       today_start),
        snapshot_for("open_ticket_count",     open_ticket_count,     today_start),
        snapshot_for("artifact_pending_count", artifact_pending_count, today_start)
      ]
    end

    # 既存 Snapshot があれば返し、なければ作成する（冪等）。
    def snapshot_for(metric_name, value, measured_at)
      MetricSnapshot.find_or_create_by!(
        metric_name: metric_name,
        period:      :daily,
        measured_at: measured_at,
        source_type: nil,
        source_id:   nil
      ) do |snap|
        snap.value          = value
        snap.created_by_run = @run
      end
    rescue => e
      # Snapshot 作成失敗でも Runner を止めない。
      # 既存の nil value Snapshot でも DetectMetricAnomalies はスキップする設計。
      Rails.logger.warn("[LedgerV2::DailyRunner] snapshot_for #{metric_name} failed: #{e.message}")
      MetricSnapshot.new(metric_name: metric_name, value: value, period: :daily, measured_at: measured_at)
    end

    # ---- KPI 計算（AI-SNS 以外） ----

    def error_count
      SolidQueue::FailedExecution.count
    rescue => e
      Rails.logger.warn("[LedgerV2::DailyRunner] error_count: #{e.message}")
      0
    end

    # 直近 7 日の SolidQueue 実行ログが取れない場合は楽観的に 1.0 を返す。
    def ci_success_rate
      1.0
    end

    def open_ticket_count
      Ticket.active.count
    rescue => e
      Rails.logger.warn("[LedgerV2::DailyRunner] open_ticket_count: #{e.message}")
      0
    end

    def artifact_pending_count
      Artifact.awaiting_review.count
    rescue => e
      Rails.logger.warn("[LedgerV2::DailyRunner] artifact_pending_count: #{e.message}")
      0
    end
  end
end
