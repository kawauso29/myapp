class CreateLinestampSubmissions < ActiveRecord::Migration[8.1]
  def change
    create_table :linestamp_submissions, if_not_exists: true do |t|
      t.references :pack, null: false, foreign_key: { to_table: :linestamp_packs }
      t.string :status, default: "draft", null: false
      t.string :line_item_id
      t.text :rejection_reason
      t.jsonb :metadata, default: {}
      t.datetime :submitted_at
      t.datetime :approved_at
      t.datetime :rejected_at
      t.timestamps
    end

    add_index :linestamp_submissions, :status, if_not_exists: true
    add_index :linestamp_submissions, [:pack_id], if_not_exists: true
  end
end
