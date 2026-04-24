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

    # @copilot コメントを送る対象 ticket_type のホワイトリスト。
    # サマリー・レコード系（quarterly_review / annual_plan 等）はコード実装なし。
    COPILOT_ELIGIBLE_TYPES = %w[improvement operations].freeze

    # Runner が自動生成するサマリーチケット（会議議事録相当）は GitHub Issue 化しない。
    # 会議結果は MeetingLedger#decisions / TicketLedger（DB）に残すことで十分。
    RUNNER_SUMMARY_TYPES = %w[quarterly_review annual_plan].freeze

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
          # copilot_eligible? でサマリー・ダミーチケットへの誤起動を防ぐ。
          if copilot_eligible?(ticket) && post_copilot_comment(ticket: ticket, issue_number: result[:issue_number])
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

    # Copilot coding agent に実装を依頼するか判定する。
    # improvement チケットは常に対象。
    # operations チケットは「default ticket」プレースホルダーを除く。
    # quarterly_review / annual_plan 等のサマリー系は対象外。
    def copilot_eligible?(ticket)
      return false unless COPILOT_ELIGIBLE_TYPES.include?(ticket.ticket_type.to_s)
      return false if ticket.title.to_s.match?(TicketLedger::DEFAULT_TICKET_TITLE_PATTERN)

      true
    end

    def post_copilot_comment(ticket:, issue_number:)
      # GitHub Copilot cloud agent の正しい起動手順:
      # 1. 実装指示コメントを先に投稿する（Copilot はアサイン時点の既存コメントを読む。
      #    アサイン後のコメントは読まれない）。
      # 2. copilot-swe-agent[bot] を assignee に追加し、agent_assignment で指示を渡す
      #    （ユーザー名は "copilot" ではなく GithubIssueService::COPILOT_AGENT_LOGIN を使う）。
      template_md = GithubMapping::CopilotInputTemplate.new(ticket).to_markdown
      body = <<~COMMENT
        @copilot このIssueの内容に従って実装してください。

        ticket_ledger ##{ticket.id} に基づく実装PRを `copilot/ledger-#{ticket.id}` ブランチで作成してください。

        #{template_md}
      COMMENT
      result = GithubIssueService.create_comment(issue_number: issue_number, body: body.strip)

      # コメント投稿後に Copilot をアサイン（既存コメントが読まれるようにするため）。
      # agent_assignment で target_repo と custom_instructions も渡す。
      GithubIssueService.add_assignees(
        issue_number: issue_number,
        assignees: [ GithubIssueService::COPILOT_AGENT_LOGIN ],
        agent_assignment: {
          target_repo: GithubIssueService::REPO,
          base_branch: "main",
          custom_instructions: "ticket_ledger ##{ticket.id} に基づく実装PRを `copilot/ledger-#{ticket.id}` ブランチで作成してください。§31 の実装ルールに従うこと。"
        }
      )
      result.present?
    rescue => e
      Rails.logger.warn("[TicketIssueSync] @copilot comment failed for ticket ##{ticket.id}: #{e.message}")
      false
    end

    def candidates
      TicketLedger
        .where(status: TARGET_STATUSES.map { |s| TicketLedger.statuses[s] })
        .where(github_issue_number: nil)
        .where.not(ticket_type: RUNNER_SUMMARY_TYPES)
    end
  end
end
