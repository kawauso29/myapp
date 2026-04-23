module Reinforcements
  # Phase C (自律成長ループ): `approved` / `planned` チケットを GitHub Issue に自動同期する。
  # §32-2 の `GithubMapping::LedgerSyncService` を全件対象でドライブし、
  # weekly → Issue → Copilot 実装ループを閉じる。
  #
  # `github_issue_number` を書き戻し済みの ticket は LedgerSyncService が skip する（冪等）。
  # DEPLOY_TOKEN 未設定時は GithubIssueService 側が nil を返すため、
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
      copilot_triggered = []

      candidates.limit(MAX_PER_RUN).find_each do |ticket|
        result = GithubMapping::LedgerSyncService.sync_ticket_to_issue(ticket)
        if result[:synced]
          synced << { ticket_id: ticket.id, issue_number: result[:issue_number] }
          # Issue 作成直後に @copilot コメントを投稿して Copilot coding agent を起動する。
          # plan_review.yml と同じパターン: Issue 本文への埋め込みでは反応しないため
          # 別コメントとして DEPLOY_TOKEN で投稿する必要がある。
          if post_copilot_comment(ticket: ticket, issue_number: result[:issue_number])
            copilot_triggered << { ticket_id: ticket.id, issue_number: result[:issue_number] }
          end
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
        copilot_triggered: copilot_triggered.size,
        details: {
          synced: synced,
          skipped: skipped,
          failed: failed,
          copilot_triggered: copilot_triggered
        }
      }
    end

    private

    def post_copilot_comment(ticket:, issue_number:)
      template_md = GithubMapping::CopilotInputTemplate.new(ticket).to_markdown
      body = <<~COMMENT
        @copilot このIssueの内容に従って実装してください。

        ticket_ledger ##{ticket.id} に基づく実装PRを `copilot/ledger-#{ticket.id}` ブランチで作成してください。

        #{template_md}
      COMMENT
      result = GithubIssueService.create_comment(issue_number: issue_number, body: body.strip)
      result.present?
    rescue => e
      Rails.logger.warn("[TicketIssueSync] @copilot comment failed for ticket ##{ticket.id}: #{e.message}")
      false
    end

    def candidates
      TicketLedger
        .where(status: TARGET_STATUSES.map { |s| TicketLedger.statuses[s] })
        .where(github_issue_number: nil)
    end
  end
end
