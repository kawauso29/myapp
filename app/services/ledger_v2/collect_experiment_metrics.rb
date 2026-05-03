# LedgerV2::CollectExperimentMetrics — v1 ExperimentLedger を readonly で観測して MetricSnapshot に保存する。
#
# 責務:
# - v1 の ExperimentLedger を readonly で参照して KPI を取得する
# - MetricSnapshot を冪等に保存する（find_or_create_by!）
# - LedgerV2 から ExperimentLedger への書き込みは一切行わない（readonly の保証）
#
# 収集指標:
#   - experiment_active_count     … 現在 active かつ期限内の実験件数
#   - experiment_expired_count    … status_active のまま期限切れになっている実験件数（要決断）
#
# 戻り値: [Array<LedgerV2::MetricSnapshot>]（保存済みまたはメモリ上の Snapshot）
#
# 設計の正本: ledger_v2_detailed_design.txt §「Phase Future 4: ExperimentLedger」
# 移行ドキュメント: docs/projects/ledger-v2-migration.md §「Ticket 26」
module LedgerV2
  class CollectExperimentMetrics
    METRIC_NAMES = %w[experiment_active_count experiment_expired_count].freeze

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
        save_snapshot("experiment_active_count",   active_count),
        save_snapshot("experiment_expired_count",  expired_count)
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
      Rails.logger.warn("[LedgerV2::CollectExperimentMetrics] save_snapshot #{metric_name} failed: #{e.message}")
      MetricSnapshot.new(metric_name: metric_name, value: value, period: @period, measured_at: @since_at)
    end

    # ---- ExperimentLedger KPI 取得（readonly） ----

    # status_active かつ期限内の実験件数
    def active_count
      ::ExperimentLedger.status_active.where("deadline >= ?", Date.current).count
    rescue => e
      Rails.logger.warn("[LedgerV2::CollectExperimentMetrics] active_count: #{e.message}")
      0
    end

    # status_active のまま deadline を過ぎた実験件数（未決定の期限切れ）
    def expired_count
      ::ExperimentLedger.status_active.where("deadline < ?", Date.current).count
    rescue => e
      Rails.logger.warn("[LedgerV2::CollectExperimentMetrics] expired_count: #{e.message}")
      0
    end
  end
end
