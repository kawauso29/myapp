# LedgerV2::AnnualRunnerJob — AnnualRunner を RunExecutor 経由で起動するジョブ。
#
# 責務:
# - RunExecutor.call(:annual_runner, ...) を呼ぶだけ
# - 手動 dispatch のみ対応。recurring.yml には登録しない（manual only）
# - dry_run: true を渡せば副作用なしで実行できる
#
# やること（人間が明示的に dispatch したときだけ）:
# - LedgerV2::AnnualRunner を通じて Quarterly Artifact を年次 draft に集約する
#
# やらないこと:
# - recurring.yml に登録しない（自動起動禁止）
# - REQUIRED_JOB_CLASSES に追加しない（スケジューラ対象外）
#
# 設計の正本: ledger_v2_detailed_design.txt §「Phase Future 5: Quarterly / Annual」
module LedgerV2
  class AnnualRunnerJob < ApplicationJob
    queue_as :default

    # @param dry_run      [Boolean]       Ticket 28 フェーズは dry_run: true を維持する。AnnualRunner は dry_run のみ許可。
    # @param trigger_type [String/Symbol] manual / console / test
    # @param triggered_by [String, nil]  呼び出し元の識別子
    def perform(dry_run: true, trigger_type: :manual, triggered_by: nil)
      LedgerV2::RunExecutor.call(
        :annual_runner,
        dry_run:,
        trigger_type:,
        triggered_by:
      )
    end
  end
end
