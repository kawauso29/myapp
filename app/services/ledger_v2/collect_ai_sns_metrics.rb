# LedgerV2::CollectAiSnsMetrics — AI-SNS の観測指標を readonly で収集し MetricSnapshot に保存する。
#
# 責務:
# - AI-SNS モデル（AiPost / AiDmThread / AiPostLike）を readonly で参照して KPI を取得する
# - MetricSnapshot を冪等に保存する（find_or_create_by!）
# - LedgerV2 から AI-SNS への書き込みは一切行わない（readonly の保証）
#
# 戻り値: [Array<LedgerV2::MetricSnapshot>]（保存済みまたはメモリ上の Snapshot）
#
# 設計の正本: ledger_v2_detailed_design.txt §「Ticket 17」
module LedgerV2
  class CollectAiSnsMetrics
    METRIC_NAMES = %w[ai_sns_posts_count ai_sns_dm_count ai_sns_reaction_count].freeze

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
        save_snapshot("ai_sns_posts_count",    posts_count),
        save_snapshot("ai_sns_dm_count",       dm_count),
        save_snapshot("ai_sns_reaction_count", reaction_count)
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
      Rails.logger.warn("[LedgerV2::CollectAiSnsMetrics] save_snapshot #{metric_name} failed: #{e.message}")
      MetricSnapshot.new(metric_name: metric_name, value: value, period: @period, measured_at: @since_at)
    end

    # ---- AI-SNS KPI 取得（readonly） ----

    def posts_count
      AiPost.where("created_at >= ?", @since_at).count
    rescue => e
      Rails.logger.warn("[LedgerV2::CollectAiSnsMetrics] posts_count: #{e.message}")
      0
    end

    def dm_count
      AiDmThread.where("created_at >= ?", @since_at).count
    rescue => e
      Rails.logger.warn("[LedgerV2::CollectAiSnsMetrics] dm_count: #{e.message}")
      0
    end

    def reaction_count
      AiPostLike.where("created_at >= ?", @since_at).count
    rescue => e
      Rails.logger.warn("[LedgerV2::CollectAiSnsMetrics] reaction_count: #{e.message}")
      0
    end
  end
end
