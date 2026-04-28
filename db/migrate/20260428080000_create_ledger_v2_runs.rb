class CreateLedgerV2Runs < ActiveRecord::Migration[8.1]
  def change
    create_table :ledger_v2_runs, if_not_exists: true do |t|
      t.string   :runner_name,               null: false
      t.integer  :status,                    null: false, default: 0
      t.integer  :trigger_type,              null: false, default: 0
      t.string   :triggered_by
      t.boolean  :dry_run,                   null: false, default: false
      t.string   :idempotency_key
      t.datetime :started_at
      t.datetime :finished_at
      t.integer  :duration_ms
      t.string   :skipped_reason
      t.string   :error_class
      t.text     :error_message
      t.string   :error_backtrace_digest
      t.integer  :created_ticket_count,      null: false, default: 0
      t.integer  :updated_ticket_count,      null: false, default: 0
      t.integer  :created_artifact_count,    null: false, default: 0
      t.integer  :created_event_count,       null: false, default: 0
      t.integer  :duplicate_prevented_count, null: false, default: 0
      t.jsonb    :metadata_json

      t.timestamps
    end

    add_index :ledger_v2_runs, :status,                                 if_not_exists: true
    add_index :ledger_v2_runs, :dry_run,                                if_not_exists: true
    add_index :ledger_v2_runs, [:runner_name, :started_at],             if_not_exists: true
    add_index :ledger_v2_runs, :idempotency_key, unique: true,
                               where: "idempotency_key IS NOT NULL",    if_not_exists: true
  end
end
