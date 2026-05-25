class DropLegacyColumnsFromLinestampTables < ActiveRecord::Migration[8.1]
  def up
    remove_column :linestamp_brands, :name if column_exists?(:linestamp_brands, :name)
    remove_column :linestamp_packs, :title if column_exists?(:linestamp_packs, :title)
    remove_column :linestamp_stamps, :emotion if column_exists?(:linestamp_stamps, :emotion)
    remove_column :linestamp_stamps, :text_overlay if column_exists?(:linestamp_stamps, :text_overlay)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
