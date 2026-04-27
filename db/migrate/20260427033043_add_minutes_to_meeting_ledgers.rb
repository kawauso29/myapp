class AddMinutesToMeetingLedgers < ActiveRecord::Migration[8.1]
  def up
    add_column :meeting_ledgers, :minutes, :jsonb, default: {}, null: false unless column_exists?(:meeting_ledgers, :minutes)
  end

  def down
    remove_column :meeting_ledgers, :minutes if column_exists?(:meeting_ledgers, :minutes)
  end
end
