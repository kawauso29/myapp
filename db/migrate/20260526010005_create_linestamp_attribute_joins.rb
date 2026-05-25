class CreateLinestampAttributeJoins < ActiveRecord::Migration[8.1]
  def change
    create_table :linestamp_brand_attribute_values, if_not_exists: true do |t|
      t.references :brand, null: false, foreign_key: { to_table: :linestamp_brands }
      t.references :attribute_value, null: false, foreign_key: { to_table: :linestamp_attribute_values }
      t.integer :weight, default: 100, comment: "0-100 ブランドにおけるこの属性の強さ"
      t.timestamps
      t.index [:brand_id, :attribute_value_id], unique: true, name: "idx_brand_av_unique"
      t.index :attribute_value_id, name: "idx_brand_av_by_value"
    end

    create_table :linestamp_pack_attribute_values, if_not_exists: true do |t|
      t.references :pack, null: false, foreign_key: { to_table: :linestamp_packs }
      t.references :attribute_value, null: false, foreign_key: { to_table: :linestamp_attribute_values }
      t.integer :weight, default: 100
      t.timestamps
      t.index [:pack_id, :attribute_value_id], unique: true, name: "idx_pack_av_unique"
      t.index :attribute_value_id, name: "idx_pack_av_by_value"
    end

    create_table :linestamp_stamp_attribute_values, if_not_exists: true do |t|
      t.references :stamp, null: false, foreign_key: { to_table: :linestamp_stamps }
      t.references :attribute_value, null: false, foreign_key: { to_table: :linestamp_attribute_values }
      t.timestamps
      t.index [:stamp_id, :attribute_value_id], unique: true, name: "idx_stamp_av_unique"
      t.index :attribute_value_id, name: "idx_stamp_av_by_value"
    end
  end
end
