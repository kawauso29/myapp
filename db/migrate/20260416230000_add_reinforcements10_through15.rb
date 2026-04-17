class AddReinforcements10Through15 < ActiveRecord::Migration[8.1]
  def change
    # 補強10: improvement 学習ループ — improvement 種別チケットの効果測定フィールド
    add_column :ticket_ledgers, :improvement_pattern_key, :string
    add_column :ticket_ledgers, :effectiveness_score, :decimal, precision: 5, scale: 4
    add_column :ticket_ledgers, :effectiveness_sample_size, :integer
    add_column :ticket_ledgers, :effectiveness_updated_at, :datetime
    add_index :ticket_ledgers, :improvement_pattern_key

    # 補強13: 外部依存 SLA — waiting_review 等での固着防止
    add_column :ticket_ledgers, :sla_deadline, :datetime
    add_column :ticket_ledgers, :sla_breach_action, :integer
    add_column :ticket_ledgers, :sla_breached_at, :datetime
    add_index :ticket_ledgers, :sla_deadline
    add_index :ticket_ledgers, :sla_breached_at

    # 補強15: 会議品質 — 会議台帳に機能性メトリクスを付与
    add_column :meeting_ledgers, :role_fill_rate, :decimal, precision: 5, scale: 4
    add_column :meeting_ledgers, :hold_item_rate, :decimal, precision: 5, scale: 4
    add_column :meeting_ledgers, :duration_minutes, :integer
    add_column :meeting_ledgers, :kpi_correlation_score, :decimal, precision: 5, scale: 4
    add_column :meeting_ledgers, :meeting_health_score, :decimal, precision: 5, scale: 4
    add_index :meeting_ledgers, :meeting_health_score

    # 補強12: role_permissions — 権限境界を DB 制約で表現
    create_table :role_permissions do |t|
      t.integer :role, null: false
      t.integer :action, null: false
      t.integer :scope, null: false
      t.string :service_id_pattern
      t.boolean :allowed, null: false, default: false
      t.boolean :requires_dual_approval, null: false, default: false
      t.integer :approver_role
      t.string :audit_reason_code_required

      t.timestamps
    end

    add_index :role_permissions, [ :role, :action, :scope ]
    add_index :role_permissions, [ :action, :allowed ]

    # 補強14: compliance_rules — PII / 景表法 / 薬機法 / 金商法などを DB 強制
    create_table :compliance_rules do |t|
      t.string :name, null: false
      t.integer :law_domain, null: false
      t.integer :scope_level, null: false
      t.string :service_id_pattern
      t.text :pattern, null: false
      t.integer :severity, null: false
      t.datetime :enforced_at
      t.integer :owner_role, null: false
      t.text :rationale

      t.timestamps
    end

    add_index :compliance_rules, [ :law_domain, :severity ]
    add_index :compliance_rules, [ :scope_level, :severity ]
    add_index :compliance_rules, :enforced_at
  end
end
