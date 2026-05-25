class MigrateExistingDataToStructuredFields < ActiveRecord::Migration[8.1]
  def up
    # Copy brand metadata fields to dedicated columns where applicable
    execute <<~SQL.squish
      UPDATE linestamp_brands
      SET concept = description
      WHERE (concept IS NULL OR concept = '') AND description IS NOT NULL AND description != ''
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
