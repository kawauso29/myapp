class CreateAuditDecisionLedgers < ActiveRecord::Migration[8.1]
  # Phase 32 / 補強6: 監査判断を正式に台帳化する。
  #
  # 既存の TicketLedger は監査拒否の「事実」は持つが、誰が / どの reason_code で
  # 拒否したかを構造化していない。§18 / §27 に従い、決定の根拠・役割・対象を
  # 独立テーブルに積み、low_effectiveness_override 等の reason_code を必須化する。
  def change
    create_table :audit_decision_ledgers do |t|
      t.bigint :target_ticket_id, null: false

      # 0: approve / 1: reject / 2: request_changes / 3: abstain
      t.integer :decision, null: false

      # reason_code の列挙は AuditDecisionLedger モデル側で管理する。
      t.string :reason_code, null: false
      t.text :reason_detail

      t.string :audit_role, null: false
      t.string :auditor

      # 0: company / 1: portfolio / 2: service / 3: cross_service
      t.integer :scope_level, null: false
      t.string :service_id

      t.bigint :source_meeting_id
      t.string :idempotency_key

      t.decimal :effectiveness_override_score, precision: 5, scale: 4

      t.datetime :decided_at, null: false
      t.timestamps
    end

    add_index :audit_decision_ledgers, :target_ticket_id
    add_index :audit_decision_ledgers, [ :decision, :reason_code ], name: "idx_audit_decision_by_reason"
    add_index :audit_decision_ledgers, :source_meeting_id
    add_index :audit_decision_ledgers, :idempotency_key, unique: true, where: "(idempotency_key IS NOT NULL)"
  end
end
