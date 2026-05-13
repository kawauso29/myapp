# LedgerV2::SyncDraftPrStatusJob — draft PR の CI 状態同期を RunExecutor 経由で起動するジョブ。
#
# 責務:
# - RunExecutor.call(:sync_draft_pr_status, ...) を呼ぶだけ
# - スケジュール実行（config/recurring.yml）と手動 dispatch に対応する
# - CI 状態の読取りと Event / metadata 記録を LedgerV2 に集約する
module LedgerV2
  class SyncDraftPrStatusJob < ApplicationJob
    queue_as :default

    def perform(dry_run: false, trigger_type: :schedule, triggered_by: nil)
      LedgerV2::RunExecutor.call(
        :sync_draft_pr_status,
        dry_run: dry_run,
        trigger_type: trigger_type,
        triggered_by: triggered_by
      )
    end
  end
end
