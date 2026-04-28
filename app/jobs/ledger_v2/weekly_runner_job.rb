# LedgerV2::WeeklyRunnerJob — WeeklyRunner を RunExecutor 経由で起動するジョブ。
#
# 責務:
# - RunExecutor.call(:weekly_runner, ...) を呼ぶだけ
# - スケジュール実行（config/recurring.yml）と手動 dispatch に対応する
# - dry_run: true を渡せば副作用なしで実行できる
#
# 設計の正本: ledger_v2_detailed_design.txt §「LedgerV2::WeeklyRunnerJob」
module LedgerV2
  class WeeklyRunnerJob < ApplicationJob
    queue_as :default

    # @param dry_run      [Boolean]       デフォルト false
    # @param trigger_type [String/Symbol] schedule / manual / console / test
    # @param triggered_by [String, nil]  呼び出し元の識別子
    def perform(dry_run: false, trigger_type: :schedule, triggered_by: nil)
      LedgerV2::RunExecutor.call(
        :weekly_runner,
        dry_run:      dry_run,
        trigger_type: trigger_type,
        triggered_by: triggered_by
      )
    end
  end
end
