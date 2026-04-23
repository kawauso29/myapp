class CreateDevInitiatives < ActiveRecord::Migration[8.1]
  def change
    create_table :dev_initiatives, if_not_exists: true do |t|
      t.string :item_key, null: false
      t.string :title, null: false
      t.string :category
      t.integer :priority, null: false, default: 1
      t.integer :status, null: false, default: 0
      t.text :kpi_hypothesis
      t.text :kpi_result
      t.string :pr_branch
      t.text :notes
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end
    add_index :dev_initiatives, :item_key, unique: true, if_not_exists: true
    add_index :dev_initiatives, :status, if_not_exists: true
  end
end
