class TicketIssueSyncJob < ApplicationJob
  queue_as :default

  # Phase C: approved / planned チケットを GitHub Issue に自動同期する。
  # 毎時走らせ、weekly → Issue → Copilot 実装ループを閉じる。
  def perform
    Reinforcements::TicketIssueSync.call
  end
end
