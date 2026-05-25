class CreateLinestampBrands < ActiveRecord::Migration[8.1]
  def change
    create_table :linestamp_brands, if_not_exists: true do |t|
      t.string :slug, null: false
      t.string :name, null: false
      t.text :description
      t.string :status, default: "planned", null: false
      t.text :brand_prompt
      t.text :base_prompt
      t.jsonb :metadata, default: {}
      t.timestamps
    end

    add_index :linestamp_brands, :slug, unique: true, if_not_exists: true
    add_index :linestamp_brands, :status, if_not_exists: true
  end
end
