# LedgerV2::MonthlyRunner — Layer C の最初の接続点。
#
# Ticket 19 では RunExecutor 経由で起動できる骨組みだけを提供する。
# Weekly 集約・Artifact 作成・定期実行は後続 Ticket で別 PR として追加する。
#
# やらないこと:
# - Artifact を作らない
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
      RunExecutor::RunnerResult.new
    end
  end
end
