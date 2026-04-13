class CreateKpiSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :kpi_snapshots do |t|
      t.string :period, null: false        # "weekly" / "daily"
      t.date   :recorded_on, null: false
      t.json   :metrics, null: false

      t.timestamps
    end

    add_index :kpi_snapshots, %i[period recorded_on], unique: true
  end
end
