module GithubMapping
  # §32-2: 台帳と GitHub 項目のマッピング（同期）サービス。
  # ticket_ledger を GitHub Issue に同期し、Issue 番号を台帳に書き戻す。
  class LedgerSyncService
    def self.sync_ticket_to_issue(ticket)
      new.sync_ticket_to_issue(ticket)
    end

    def sync_ticket_to_issue(ticket)
      return skip_result("already synced") if ticket.github_issue_number.present?

      issue_data = IssueBuilder.build(ticket)
      result = GithubIssueService.create_issue(
        title: issue_data[:title],
        body: issue_data[:body],
        labels: issue_data[:labels]
      )

      if result && result["number"]
        ticket.update!(
          github_issue_number: result["number"],
          github_synced_at: Time.current
        )
        { synced: true, issue_number: result["number"] }
      else
        { synced: false, error: "GitHub Issue creation failed" }
      end
    end

    def self.sync_ticket_to_pr(ticket, docs_update_required: false, tech_record_update_required: false)
      new.sync_ticket_to_pr(ticket, docs_update_required:, tech_record_update_required:)
    end

    def sync_ticket_to_pr(ticket, docs_update_required: false, tech_record_update_required: false)
      return skip_result("already synced PR") if ticket.github_pr_number.present?

      pr_data = PrBuilder.build(ticket,
                                docs_update_required:,
                                tech_record_update_required:)
      result = GithubPrService.create_pr(
        title: pr_data[:title],
        body: pr_data[:body],
        branch_prefix: "copilot/ledger-#{ticket.id}"
      )

      if result && result["number"]
        ticket.update!(
          github_pr_number: result["number"],
          github_synced_at: Time.current
        )
        { synced: true, pr_number: result["number"] }
      else
        { synced: false, error: "GitHub PR creation failed" }
      end
    end

    private

    def skip_result(reason)
      { synced: false, skipped: true, reason: reason }
    end
  end
end
