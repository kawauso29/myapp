class AddStructuredFieldsToLinestampBrands < ActiveRecord::Migration[8.1]
  def change
    change_table :linestamp_brands do |t|
      t.string :character_name
      t.string :series_name
      t.text   :two_part_definition
      t.text   :concept
      t.text   :target_audience
      t.jsonb  :target_axes, default: {}
      t.jsonb  :tone_axes, default: {}
      t.text   :purpose_background
      t.jsonb  :character_parts, default: {}
      t.jsonb  :font_spec, default: {}
      t.string :primary_color, default: "#FFFFFF"
      t.string :background_color_for_gen, default: "#3CB371"
    end
  end
end
