class CreateKpiAndServiceLedgers < ActiveRecord::Migration[8.1]
  def change
    create_table :kpi_ledgers do |t|
      t.string :kpi_key, null: false
      t.integer :scope_level, null: false
      t.string :service_id
      t.string :name, null: false
      t.text :description
      t.jsonb :target_value, null: false, default: {}
      t.jsonb :current_value, null: false, default: {}
      t.integer :status, null: false, default: 0

      t.timestamps
    end

    add_index :kpi_ledgers, :kpi_key, unique: true
    add_index :kpi_ledgers, [ :scope_level, :service_id ]

    create_table :service_ledgers do |t|
      t.string :service_id, null: false
      t.integer :scope_level, null: false, default: 2
      t.string :business_owner, null: false
      t.integer :status, null: false, default: 0
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :service_ledgers, :service_id, unique: true
    add_index :service_ledgers, :scope_level
  end
end
