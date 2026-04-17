class AddPhase27Through30Fields < ActiveRecord::Migration[8.0]
  def change
    # §33.4 R1: 会議周期可変設計 — meeting_definitions に allowed_cycles を追加
    add_column :meeting_definitions, :allowed_cycles, :jsonb, default: [], null: false

    # §33.4 R2: ロール対立マトリクス — role_permissions に tiebreaker_role を追加
    add_column :role_permissions, :tiebreaker_role, :integer

    # §33.4 R3: サービス撤退/ピボット — ticket_ledgers に github_issue_number と risk_level を追加
    add_column :ticket_ledgers, :github_issue_number, :integer
    add_column :ticket_ledgers, :risk_level, :integer, default: 0

    # §32-1: GitHub マッピング用
    add_column :ticket_ledgers, :github_pr_number, :integer
    add_column :ticket_ledgers, :github_synced_at, :datetime

    # §33.4 R4: 実験台帳 — experiment_ledgers
    create_table :experiment_ledgers do |t|
      t.string  :service_id, null: false
      t.integer :scope_level, null: false, default: 2
      t.string  :hypothesis, null: false
      t.jsonb   :kpi_targets, default: [], null: false
      t.date    :deadline, null: false
      t.integer :status, default: 0, null: false
      t.string  :auto_decision
      t.datetime :decided_at
      t.string  :decision_reason
      t.string  :created_by
      t.bigint  :source_ticket_id
      t.jsonb   :linked_kpis, default: [], null: false

      t.timestamps
    end

    add_index :experiment_ledgers, :service_id
    add_index :experiment_ledgers, :status
    add_index :experiment_ledgers, :deadline
  end
end
