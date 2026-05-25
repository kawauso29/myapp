class AddRepresentativeStampsToLinestampPacks < ActiveRecord::Migration[8.1]
  def change
    change_table :linestamp_packs do |t|
      t.references :main_source_stamp, foreign_key: { to_table: :linestamp_stamps }, null: true
      t.references :tab_source_stamp, foreign_key: { to_table: :linestamp_stamps }, null: true
    end
  end
end
