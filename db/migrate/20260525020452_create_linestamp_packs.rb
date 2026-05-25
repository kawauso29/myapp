class CreateLinestampPacks < ActiveRecord::Migration[8.1]
  def change
    create_table :linestamp_packs, if_not_exists: true do |t|
      t.references :brand, null: false, foreign_key: { to_table: :linestamp_brands }
      t.references :approver, foreign_key: { to_table: :users }
      t.string :title, null: false
      t.integer :position, default: 1, null: false
      t.string :status, default: "planned", null: false
      t.text :sheet_prompt
      t.jsonb :metadata, default: {}
      t.datetime :approved_at
      t.timestamps
    end

    add_index :linestamp_packs, :status, if_not_exists: true
    add_index :linestamp_packs, [:brand_id, :position], unique: true, if_not_exists: true
  end
end
