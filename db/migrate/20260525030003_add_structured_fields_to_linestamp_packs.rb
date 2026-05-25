class AddStructuredFieldsToLinestampPacks < ActiveRecord::Migration[8.1]
  def change
    change_table :linestamp_packs do |t|
      t.string :slug
      t.string :series_theme
      t.string :layer
      t.text   :world_view
      t.jsonb  :usage_scenes, default: []
      t.jsonb  :target_emotions, default: []
      t.text   :excluded_elements
      t.references :image_spec, foreign_key: { to_table: :linestamp_image_specs }
    end

    add_index :linestamp_packs, [:brand_id, :slug], unique: true, if_not_exists: true
  end
end
