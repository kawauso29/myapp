# LedgerV2::CollectKnowledgeMetrics — v1 KnowledgeLedger を readonly で観測して MetricSnapshot に保存する。
#
# 責務:
# - v1 の KnowledgeLedger を readonly で参照して KPI を取得する
# - MetricSnapshot を冪等に保存する（find_or_create_by!）
# - LedgerV2 から KnowledgeLedger への書き込みは一切行わない（readonly の保証）
#
# 収集指標:
#   - knowledge_incident_count      … period 内に作成された incident 種別の知識エントリ件数
#   - knowledge_stale_draft_count   … draft のまま 7 日以上放置されている知識エントリ件数
#
# 戻り値: [Array<LedgerV2::MetricSnapshot>]（保存済みまたはメモリ上の Snapshot）
#
# 設計の正本: ledger_v2_detailed_design.txt §「Phase Future 3: KnowledgeLedger」
# 移行ドキュメント: docs/projects/ledger-v2-migration.md §「Ticket 25」
module LedgerV2
  class CollectKnowledgeMetrics
    METRIC_NAMES = %w[knowledge_incident_count knowledge_stale_draft_count].freeze

    # draft とみなす最長許容日数（これを超えると stale と判定）
    STALE_DRAFT_DAYS = 7

    # @param run      [LedgerV2::Run]  RunExecutor が生成した Run
    # @param period   [Symbol]         :daily / :weekly
    # @param since_at [Time]           集計開始時刻（period の始まり）
    # @return [Array<LedgerV2::MetricSnapshot>]
    def self.call(run:, period: :daily, since_at: Time.current.beginning_of_day)
      new(run: run, period: period, since_at: since_at).call
    end

    def initialize(run:, period:, since_at:)
      @run      = run
      @period   = period
      @since_at = since_at
    end

    def call
      [
        save_snapshot("knowledge_incident_count",    incident_count),
        save_snapshot("knowledge_stale_draft_count", stale_draft_count)
      ]
    end

    private

    # 既存 Snapshot があれば返し、なければ作成する（冪等）。
    def save_snapshot(metric_name, value)
      MetricSnapshot.find_or_create_by!(
        metric_name: metric_name,
        period:      @period,
        measured_at: @since_at,
        source_type: nil,
        source_id:   nil
      ) do |snap|
        snap.value          = value
        snap.created_by_run = @run
      end
    rescue => e
      Rails.logger.warn("[LedgerV2::CollectKnowledgeMetrics] save_snapshot #{metric_name} failed: #{e.message}")
      MetricSnapshot.new(metric_name: metric_name, value: value, period: @period, measured_at: @since_at)
    end

    # ---- KnowledgeLedger KPI 取得（readonly） ----

    # period 内に作成された incident 種別の知識エントリ件数
    def incident_count
      ::KnowledgeLedger.kind_incident.where("created_at >= ?", @since_at).count
    rescue => e
      Rails.logger.warn("[LedgerV2::CollectKnowledgeMetrics] incident_count: #{e.message}")
      0
    end

    # draft のまま STALE_DRAFT_DAYS 日以上放置されている知識エントリ件数
    def stale_draft_count
      stale_threshold = @since_at - STALE_DRAFT_DAYS.days
      ::KnowledgeLedger.status_draft.where("created_at < ?", stale_threshold).count
    rescue => e
      Rails.logger.warn("[LedgerV2::CollectKnowledgeMetrics] stale_draft_count: #{e.message}")
      0
    end
  end
end
