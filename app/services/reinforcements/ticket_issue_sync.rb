module Reinforcements
  # Phase C (自律成長ループ): `approved` / `planned` チケットを GitHub Issue に自動同期する。
  # §32-2 の `GithubMapping::LedgerSyncService` を全件対象でドライブし、
  # weekly → Issue → Copilot 実装ループを閉じる。
  #
  # `github_issue_number` を書き戻し済みの ticket は LedgerSyncService が skip する（冪等）。
  # GITHUB_DEPLOY_TOKEN 未設定時は GithubIssueService 側が nil を返すため、
  # ここでは結果を `failed` に計上するだけにとどめる（壊さない運用）。
  class TicketIssueSync
    # 「weekly で承認された → Issue に流す」境界をどこに置くかの設計判断。
    # draft は弾く（承認前）、completed/cancelled は既に閉じている。
    TARGET_STATUSES = %i[approved planned executing waiting_review].freeze
    MAX_PER_RUN = 20 # 一度に大量 Issue 化するのを防ぐ上限

    def self.call
      new.call
    end

    def call
      synced = []
      skipped = []
      failed = []

      candidates.limit(MAX_PER_RUN).find_each do |ticket|
        result = GithubMapping::LedgerSyncService.sync_ticket_to_issue(ticket)
        if result[:synced]
          synced << { ticket_id: ticket.id, issue_number: result[:issue_number] }
        elsif result[:skipped]
          skipped << { ticket_id: ticket.id, reason: result[:reason] }
        else
          failed << { ticket_id: ticket.id, error: result[:error] }
        end
      end

      {
        synced: synced.size,
        skipped: skipped.size,
        failed: failed.size,
        details: {
          synced: synced,
          skipped: skipped,
          failed: failed
        }
      }
    end

    private

    def candidates
      TicketLedger
        .where(status: TARGET_STATUSES.map { |s| TicketLedger.statuses[s] })
        .where(github_issue_number: nil)
    end
  end
end
