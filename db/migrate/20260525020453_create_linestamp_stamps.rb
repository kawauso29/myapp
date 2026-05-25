class CreateLinestampStamps < ActiveRecord::Migration[8.1]
  def change
    create_table :linestamp_stamps, if_not_exists: true do |t|
      t.references :pack, null: false, foreign_key: { to_table: :linestamp_packs }
      t.integer :position, null: false
      t.string :status, default: "planned", null: false
      t.text :prompt
      t.string :emotion
      t.string :text_overlay
      t.jsonb :metadata, default: {}
      t.timestamps
    end

    add_index :linestamp_stamps, :status, if_not_exists: true
    add_index :linestamp_stamps, [:pack_id, :position], unique: true, if_not_exists: true
  end
end
