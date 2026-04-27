class AddCopilotTriggeredAtToTicketLedgers < ActiveRecord::Migration[8.1]
  def up
    add_column :ticket_ledgers, :copilot_triggered_at, :datetime unless column_exists?(:ticket_ledgers, :copilot_triggered_at)
    add_index :ticket_ledgers, :copilot_triggered_at, if_not_exists: true
  end

  def down
    remove_index :ticket_ledgers, :copilot_triggered_at, if_exists: true
    remove_column :ticket_ledgers, :copilot_triggered_at, if_exists: true
  end
end
