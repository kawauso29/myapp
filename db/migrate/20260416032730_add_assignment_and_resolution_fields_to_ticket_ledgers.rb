class AddAssignmentAndResolutionFieldsToTicketLedgers < ActiveRecord::Migration[8.1]
  def change
    add_column :ticket_ledgers, :assignee, :string
    add_column :ticket_ledgers, :due_date, :date
    add_column :ticket_ledgers, :resolved_at, :datetime
  end
end
