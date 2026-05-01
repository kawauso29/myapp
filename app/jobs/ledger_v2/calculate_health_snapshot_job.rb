# LedgerV2::CalculateHealthSnapshotJob — HealthSnapshot を定期生成するジョブ。
#
# 責務:
# - LedgerV2::CalculateHealthSnapshot.call(period: :daily) を呼ぶだけ
# - スケジュール実行（config/recurring.yml）と手動 dispatch に対応する
# - 圧縮時間軸（daily = 30 分）に揃え、1 snapshot = 1 圧縮日として観察を加速する
#
# 設計の正本: ledger_v2_detailed_design.txt §「LedgerV2::CalculateHealthSnapshot」
module LedgerV2
  class CalculateHealthSnapshotJob < ApplicationJob
    queue_as :default

    # @param period  [Symbol]  :daily または :weekly（デフォルト :daily）
    # @param dry_run [Boolean] デフォルト false
    def perform(period: :daily, dry_run: false)
      LedgerV2::CalculateHealthSnapshot.call(period: period, dry_run: dry_run)
    end
  end
end
