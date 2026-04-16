class CreateCostAndOperatorOverrideLedgers < ActiveRecord::Migration[8.1]
  def change
    # 補強11: cost_ledger — 判断・会議・ジョブ・サービス単位のコスト記録
    create_table :cost_ledgers do |t|
      t.integer :subject_type, null: false
      t.string :subject_id, null: false
      t.integer :scope_level, null: false
      t.string :service_id
      t.string :business_unit_id
      t.decimal :amount_jpy, precision: 14, scale: 2, null: false, default: 0
      t.integer :source, null: false
      t.string :source_detail
      t.datetime :incurred_at, null: false
      t.datetime :recorded_at, null: false, default: -> { "CURRENT_TIMESTAMP" }

      t.references :source_meeting, foreign_key: { to_table: :meeting_ledgers }
      t.references :source_ticket, foreign_key: { to_table: :ticket_ledgers }
      t.string :source_artifact_id

      t.timestamps
    end

    add_index :cost_ledgers, [ :subject_type, :subject_id ]
    add_index :cost_ledgers, [ :scope_level, :service_id ]
    add_index :cost_ledgers, :incurred_at

    # 補強16: operator_override_ledger — 人間オペレーター専用のキルスイッチ
    create_table :operator_override_ledgers do |t|
      t.integer :action, null: false
      t.integer :scope_level, null: false
      t.string :service_id
      t.string :operator, null: false
      t.datetime :started_at, null: false
      t.datetime :lifted_at
      t.text :reason, null: false
      t.string :linked_stop_ledger_id

      t.timestamps
    end

    add_index :operator_override_ledgers, [ :action, :lifted_at ]
    add_index :operator_override_ledgers, [ :scope_level, :service_id, :lifted_at ],
              name: "idx_operator_override_scope_lifted"
  end
end
