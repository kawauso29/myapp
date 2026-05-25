class CreateLinestampThemeJoins < ActiveRecord::Migration[8.1]
  def change
    create_table :linestamp_brand_communication_themes, if_not_exists: true do |t|
      t.references :brand, null: false, foreign_key: { to_table: :linestamp_brands }
      t.references :communication_theme, null: false, foreign_key: { to_table: :linestamp_communication_themes }
      t.integer :weight, default: 100, comment: "0-100 ブランドにとってのこのテーマの中心度"
      t.timestamps
      t.index [:brand_id, :communication_theme_id], unique: true, name: "idx_brand_ct_unique"
      t.index :communication_theme_id, name: "idx_brand_ct_by_theme"
    end

    create_table :linestamp_pack_communication_themes, if_not_exists: true do |t|
      t.references :pack, null: false, foreign_key: { to_table: :linestamp_packs }
      t.references :communication_theme, null: false, foreign_key: { to_table: :linestamp_communication_themes }
      t.integer :weight, default: 100
      t.timestamps
      t.index [:pack_id, :communication_theme_id], unique: true, name: "idx_pack_ct_unique"
      t.index :communication_theme_id, name: "idx_pack_ct_by_theme"
    end

    create_table :linestamp_stamp_communication_themes, if_not_exists: true do |t|
      t.references :stamp, null: false, foreign_key: { to_table: :linestamp_stamps }
      t.references :communication_theme, null: false, foreign_key: { to_table: :linestamp_communication_themes }
      t.boolean :primary, default: false, comment: "true ならこのスタンプの主テーマ(必ず1つは true)"
      t.timestamps
      t.index [:stamp_id, :communication_theme_id], unique: true, name: "idx_stamp_ct_unique"
      t.index :communication_theme_id, name: "idx_stamp_ct_by_theme"
    end
  end
end
