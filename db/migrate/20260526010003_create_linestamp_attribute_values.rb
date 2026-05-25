class CreateLinestampAttributeValues < ActiveRecord::Migration[8.1]
  def change
    create_table :linestamp_attribute_values, if_not_exists: true do |t|
      t.references :axis, null: false, foreign_key: { to_table: :linestamp_attribute_axes }
      t.string  :slug,    null: false, comment: "英小文字スネーク 例: gentle / animal / age_30s / remote"
      t.string  :name,    null: false, comment: "日本語 例: ゆるい / 動物 / 30代 / 在宅"
      t.text    :description
      t.integer :position, default: 0
      t.boolean :active, default: true, null: false
      t.timestamps

      t.index [:axis_id, :slug], unique: true
      t.index :active
    end
  end
end
