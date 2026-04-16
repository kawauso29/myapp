class AddGithubIssueFieldsToTicketLedgers < ActiveRecord::Migration[8.1]
  def change
    add_column :ticket_ledgers, :github_repo, :string
    add_column :ticket_ledgers, :github_issue_number, :integer
    add_column :ticket_ledgers, :github_issue_url, :string
    add_column :ticket_ledgers, :github_issue_synced_at, :datetime
    add_column :ticket_ledgers, :github_issue_sync_status, :string
    add_column :ticket_ledgers, :github_issue_sync_error, :text
  end
end
