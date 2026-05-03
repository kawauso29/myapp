# LedgerV2::CollectCustomerFeedback — v1 CustomerFeedbackLedger を readonly で観測して MetricSnapshot に保存する。
#
# 責務:
# - v1 の CustomerFeedbackLedger を readonly で参照して KPI を取得する
# - MetricSnapshot を冪等に保存する（find_or_create_by!）
# - LedgerV2 から CustomerFeedbackLedger への書き込みは一切行わない（readonly の保証）
# - Ticket の自動生成は行わない（FeedbackからTicketを作る場合は人間承認が必要）
#
# 収集指標:
#   - customer_feedback_new_count       … 未トリアージのフィードバック件数（status: new_feedback）
#   - customer_feedback_escalated_count … エスカレート済みのフィードバック件数（status: escalated）
#
# 戻り値: [Array<LedgerV2::MetricSnapshot>]（保存済みまたはメモリ上の Snapshot）
#
# 設計の正本: ledger_v2_detailed_design.txt §「Phase Future 2: CustomerFeedbackLedger」
# 移行ドキュメント: docs/projects/ledger-v2-migration.md §「Ticket 24」
module LedgerV2
  class CollectCustomerFeedback
    METRIC_NAMES = %w[customer_feedback_new_count customer_feedback_escalated_count].freeze

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
        save_snapshot("customer_feedback_new_count",       new_count),
        save_snapshot("customer_feedback_escalated_count", escalated_count)
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
      Rails.logger.warn("[LedgerV2::CollectCustomerFeedback] save_snapshot #{metric_name} failed: #{e.message}")
      MetricSnapshot.new(metric_name: metric_name, value: value, period: @period, measured_at: @since_at)
    end

    # ---- CustomerFeedbackLedger KPI 取得（readonly） ----

    # 未トリアージ（new_feedback）のフィードバック件数
    def new_count
      ::CustomerFeedbackLedger.status_new_feedback.count
    rescue => e
      Rails.logger.warn("[LedgerV2::CollectCustomerFeedback] new_count: #{e.message}")
      0
    end

    # エスカレート済みのフィードバック件数（period 内に受信したもの）
    def escalated_count
      ::CustomerFeedbackLedger.status_escalated.where("received_at >= ?", @since_at).count
    rescue => e
      Rails.logger.warn("[LedgerV2::CollectCustomerFeedback] escalated_count: #{e.message}")
      0
    end
  end
end
