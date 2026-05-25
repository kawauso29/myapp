class CreateLinestampAttributeAxes < ActiveRecord::Migration[8.1]
  def change
    create_table :linestamp_attribute_axes, if_not_exists: true do |t|
      t.string  :slug,  null: false, comment: "tone / motif / demographic / setting"
      t.string  :name,  null: false, comment: "日本語 例: トーン / モチーフ / デモグラフィ / シーン"
      t.string  :kind,  null: false, comment: "tone | motif | demographic | setting"
      t.text    :description
      t.integer :position, default: 0
      t.boolean :active, default: true, null: false
      t.timestamps

      t.index :slug, unique: true
      t.index :kind
    end
  end
end
