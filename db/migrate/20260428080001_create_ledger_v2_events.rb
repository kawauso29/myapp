class CreateLedgerV2Events < ActiveRecord::Migration[8.1]
  def change
    create_table :ledger_v2_events, if_not_exists: true do |t|
      t.bigint   :run_id,        null: false
      t.string   :event_type,    null: false
      t.string   :source_type
      t.bigint   :source_id
      t.string   :subject_type
      t.bigint   :subject_id
      t.integer  :severity,      null: false, default: 1
      t.text     :message
      t.jsonb    :payload_json
      t.datetime :occurred_at,   null: false

      t.timestamps
    end

    add_index :ledger_v2_events, :run_id,                               if_not_exists: true
    add_index :ledger_v2_events, :event_type,                           if_not_exists: true
    add_index :ledger_v2_events, [:source_type, :source_id],            if_not_exists: true
    add_index :ledger_v2_events, [:subject_type, :subject_id],          if_not_exists: true
    add_index :ledger_v2_events, :occurred_at,                          if_not_exists: true
    add_foreign_key :ledger_v2_events, :ledger_v2_runs, column: :run_id, if_not_exists: true
  end
end
