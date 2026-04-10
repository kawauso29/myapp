class CreateSearchLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :search_logs do |t|
      t.references :user, null: true, foreign_key: true
      t.references :ai_user, null: true, foreign_key: true
      t.string :query, null: false
      t.integer :search_type, null: false
      t.integer :results_count, default: 0, null: false

      t.timestamps
    end

    add_index :search_logs, :created_at
    add_index :search_logs, :search_type
    add_index :search_logs, :query
  end
end
