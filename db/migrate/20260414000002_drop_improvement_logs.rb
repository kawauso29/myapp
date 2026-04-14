class DropImprovementLogs < ActiveRecord::Migration[8.1]
  def up
    drop_table :improvement_logs
  end

  def down
    create_table :improvement_logs do |t|
      t.json :observation, null: false
      t.text :summary
      t.json :quick_win_results
      t.json :feature_proposals
      t.integer :applied_quick_wins, default: 0, null: false
      t.json :created_pr_numbers
      t.timestamps
    end
    add_index :improvement_logs, :created_at
  end
end
