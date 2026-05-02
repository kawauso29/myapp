# LedgerV2::MonthlyRunner — Layer C の最初の接続点。
#
# RunExecutor 経由で起動し、Weekly Artifact を月次 draft に集約する。
# Ticket 20 時点では dry_run のみ許可し、DB 書き込みは行わない。
#
# やらないこと:
# - Artifact を DB に保存しない
# - Ticket を変更しない
# - 自動 PR を作らない
# - 自動マージしない
# - v1 MonthlyOpsRunner のコードを移植しない
#
# 設計の正本: ledger_v2_detailed_design.txt §「Phase Future 1: MonthlyRunner」
module LedgerV2
  class MonthlyRunner
    # @param run      [LedgerV2::Run]  RunExecutor が生成した Run
    # @param dry_run  [Boolean]        Ticket 19 では true のみ許可
    # @return [LedgerV2::RunExecutor::RunnerResult]
    def self.call(run:, dry_run: false, **)
      raise ArgumentError, "LedgerV2::MonthlyRunner は dry_run: true のみ許可されています" unless dry_run

      new(run: run).call
    end

    def initialize(run:)
      @run = run
    end

    def call
      BuildMonthlyArtifact.call(
        run:,
        weekly_artifacts: collect_weekly_artifacts,
        active_tickets: collect_active_tickets
      )

      RunExecutor::RunnerResult.new
    end

    private

    attr_reader :run

    def collect_weekly_artifacts
      since = Time.current - BuildMonthlyArtifact::MONTHLY_PERIOD_DAYS.days
      Artifact.where(artifact_type: "weekly_review")
              .where("created_at >= ?", since)
              .order(created_at: :asc)
              .to_a
    rescue => e
      log_collection_error("collect_weekly_artifacts", e)
      []
    end

    def collect_active_tickets
      Ticket.active.order(created_at: :asc).to_a
    rescue => e
      log_collection_error("collect_active_tickets", e)
      []
    end

    def log_collection_error(source, error)
      backtrace = Array(error.backtrace).first(5).join("\n")
      Rails.logger.warn("[LedgerV2::MonthlyRunner] #{source} failed: #{error.class}: #{error.message}\n#{backtrace}")
    end
  end
end
