class CreateMarketSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :market_snapshots do |t|
      t.datetime :captured_at, null: false
      t.string :state, null: false
      t.float :state_confidence
      t.float :vix
      t.float :dxy
      t.float :nas100_price
      t.float :nas100_volume
      t.jsonb :raw_data

      t.timestamps
    end
    add_index :market_snapshots, :captured_at
  end
end
