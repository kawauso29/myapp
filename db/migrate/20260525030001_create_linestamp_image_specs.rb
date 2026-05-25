class CreateLinestampImageSpecs < ActiveRecord::Migration[8.1]
  def change
    create_table :linestamp_image_specs, if_not_exists: true do |t|
      t.string  :slug, null: false
      t.string  :name, null: false
      t.integer :width, null: false
      t.integer :height, null: false
      t.integer :margin_px, default: 10
      t.string  :background, default: "transparent"
      t.jsonb   :font_specs, default: []
      t.boolean :active, default: true
      t.timestamps
    end

    add_index :linestamp_image_specs, :slug, unique: true, if_not_exists: true
  end
end
