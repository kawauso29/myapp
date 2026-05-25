class BackfillLegacyColumnsToStructuredFields < ActiveRecord::Migration[8.1]
  def up
    # Brand: name -> character_name, series_name
    execute <<~SQL.squish
      UPDATE linestamp_brands
      SET character_name = name
      WHERE character_name IS NULL OR character_name = ''
    SQL
    execute <<~SQL.squish
      UPDATE linestamp_brands
      SET series_name = name
      WHERE series_name IS NULL OR series_name = ''
    SQL

    # Pack: title -> series_theme, generate slug
    execute <<~SQL.squish
      UPDATE linestamp_packs
      SET series_theme = title
      WHERE series_theme IS NULL OR series_theme = ''
    SQL
    execute <<~SQL.squish
      UPDATE linestamp_packs
      SET slug = CONCAT('pack_', LPAD(position::text, 3, '0'))
      WHERE slug IS NULL OR slug = ''
    SQL

    # Stamp: text_overlay -> label, emotion -> intent
    execute <<~SQL.squish
      UPDATE linestamp_stamps
      SET label = text_overlay
      WHERE (label IS NULL OR label = '') AND text_overlay IS NOT NULL AND text_overlay != ''
    SQL
    execute <<~SQL.squish
      UPDATE linestamp_stamps
      SET intent = emotion
      WHERE (intent IS NULL OR intent = '') AND emotion IS NOT NULL AND emotion != ''
    SQL

    # Set default image_spec_id on packs that don't have one
    execute <<~SQL.squish
      UPDATE linestamp_packs
      SET image_spec_id = (SELECT id FROM linestamp_image_specs WHERE slug = 'line_main_370x320' LIMIT 1)
      WHERE image_spec_id IS NULL
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
