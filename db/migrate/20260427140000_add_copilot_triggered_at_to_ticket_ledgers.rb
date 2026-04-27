class AddCopilotTriggeredAtToTicketLedgers < ActiveRecord::Migration[8.1]
  def change
    add_column :ticket_ledgers, :copilot_triggered_at, :datetime
    add_index :ticket_ledgers, :copilot_triggered_at
  end
end
