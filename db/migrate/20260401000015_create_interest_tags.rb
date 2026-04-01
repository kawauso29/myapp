class CreateInterestTags < ActiveRecord::Migration[8.1]
  def change
    create_table :interest_tags do |t|
      t.string  :name,        null: false
      t.string  :category
      t.integer :usage_count, null: false, default: 0

      t.timestamps

      t.index :name,        unique: true
      t.index :category
      t.index :usage_count
    end
  end
end
