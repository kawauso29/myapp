# LedgerV2::AnnualRunner — Phase G-4 #4 の完結点（Quarterly / Annual）。
#
# RunExecutor 経由で起動し、Quarterly Artifact を年次 draft に集約する。
# Ticket 28 時点では dry_run のみ許可し、DB 書き込みは行わない。
# 自動実行は禁止。人間が手動で AnnualRunnerJob を dispatch する。
#
# やらないこと:
# - Artifact を DB に保存しない
# - Ticket を変更しない
# - 自動 PR を作らない
# - 自動マージしない
# - v1 AnnualPlanRunner のコードを移植しない
# - recurring.yml には登録しない（manual only）
#
# 設計の正本: ledger_v2_detailed_design.txt §「Phase Future 5: Quarterly / Annual」
module LedgerV2
  class AnnualRunner
    # @param run      [LedgerV2::Run]  RunExecutor が生成した Run
    # @param dry_run  [Boolean]        Ticket 28 では true のみ許可
    # @return [LedgerV2::RunExecutor::RunnerResult]
    def self.call(run:, dry_run: false, **)
      raise ArgumentError, "LedgerV2::AnnualRunner は dry_run: true のみ許可されています" unless dry_run

      new(run: run).call
    end

    def initialize(run:)
      @run = run
    end

    def call
      BuildAnnualArtifact.call(
        run:,
        quarterly_artifacts: collect_quarterly_artifacts,
        active_tickets:      collect_active_tickets
      )

      RunExecutor::RunnerResult.new
    end

    private

    attr_reader :run

    def collect_quarterly_artifacts
      since = Time.current - BuildAnnualArtifact::ANNUAL_PERIOD_DAYS.days
      Artifact.where(artifact_type: "quarterly_review")
              .where("created_at >= ?", since)
              .order(created_at: :asc)
              .to_a
    rescue => e
      log_collection_error("collect_quarterly_artifacts", e)
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
      Rails.logger.warn("[LedgerV2::AnnualRunner] #{source} failed: #{error.class}: #{error.message}\n#{backtrace}")
    end
  end
end
