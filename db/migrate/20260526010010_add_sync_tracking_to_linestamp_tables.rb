# frozen_string_literal: true

class AddSyncTrackingToLinestampTables < ActiveRecord::Migration[8.0]
  def change
    add_column :linestamp_brands, :synced_at, :datetime, if_not_exists: true
    add_column :linestamp_brands, :imported_from, :string, if_not_exists: true

    add_column :linestamp_packs, :synced_at, :datetime, if_not_exists: true
    add_column :linestamp_packs, :imported_from, :string, if_not_exists: true

    add_column :linestamp_stamps, :synced_at, :datetime, if_not_exists: true
    add_column :linestamp_stamps, :imported_from, :string, if_not_exists: true

    add_column :linestamp_researches, :synced_at, :datetime, if_not_exists: true
    add_column :linestamp_researches, :imported_from, :string, if_not_exists: true
  end
end
