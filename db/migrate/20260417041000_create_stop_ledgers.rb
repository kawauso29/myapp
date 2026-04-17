class CreateStopLedgers < ActiveRecord::Migration[8.1]
  # Phase 33 / 補強7: 自動停止（Emergency Stop）を正式に台帳化する。
  #
  # §18 で定義された停止条件が成立した瞬間を 1 レコードとして記録し、
  # 解除（lifted_at）までを監査できるようにする。`operator_override_ledgers` が
  # 人手によるキルスイッチ、こちらはルール駆動の自動停止を扱う。
  def change
    create_table :stop_ledgers do |t|
      # 0: kpi_breach / 1: error_spike / 2: cost_runaway / 3: security_incident /
      # 4: compliance_violation / 5: manual_escalation
      t.integer :trigger_type, null: false
      t.string :trigger_detail

      # 0: company / 1: portfolio / 2: service / 3: cross_service
      t.integer :scope_level, null: false
      t.string :service_id

      # 0: active / 1: lifted / 2: escalated
      t.integer :status, default: 0, null: false

      t.datetime :started_at, null: false
      t.datetime :lifted_at
      t.string :lifted_by
      t.text :lift_reason

      # KPI 自動停止の場合は kpi_ledger.kpi_key 等を JSON で記録する
      t.jsonb :evidence, default: {}, null: false

      t.bigint :source_meeting_id
      t.bigint :source_ticket_id
      t.string :idempotency_key

      t.timestamps
    end

    add_index :stop_ledgers, [ :status, :trigger_type ]
    add_index :stop_ledgers, [ :scope_level, :service_id, :lifted_at ], name: "idx_stop_ledger_scope_lifted"
    add_index :stop_ledgers, :source_meeting_id
    add_index :stop_ledgers, :source_ticket_id
    add_index :stop_ledgers, :idempotency_key, unique: true, where: "(idempotency_key IS NOT NULL)"
  end
end
