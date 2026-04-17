class CreateHrAndOrgLedgers < ActiveRecord::Migration[8.1]
  # Phase 38 / §19: 人事評価と組織再編を正式台帳化する（スケルトン）。
  #
  # 現時点ではモデル + バリデーションのみ。実評価ロジックは 38b で積む。
  def change
    create_table :hr_evaluation_ledgers do |t|
      t.string :subject_role, null: false
      t.string :subject_agent
      # 評価期間
      t.date :period_start, null: false
      t.date :period_end, null: false

      # 0: company / 1: portfolio / 2: service / 3: cross_service
      t.integer :scope_level, null: false
      t.string :service_id

      # 評価スコア（0.0〜1.0）
      t.decimal :score, precision: 5, scale: 4

      # 0: draft / 1: reviewed / 2: finalized
      t.integer :status, default: 0, null: false

      t.jsonb :evidence, default: {}, null: false
      t.jsonb :criteria, default: {}, null: false

      t.bigint :source_meeting_id
      t.string :idempotency_key

      t.timestamps
    end

    add_index :hr_evaluation_ledgers, [ :subject_role, :period_end ], name: "idx_hr_evaluation_role_period"
    add_index :hr_evaluation_ledgers, :source_meeting_id
    add_index :hr_evaluation_ledgers, :idempotency_key, unique: true, where: "(idempotency_key IS NOT NULL)"

    create_table :org_change_ledgers do |t|
      # 0: role_create / 1: role_retire / 2: team_split / 3: team_merge / 4: reporting_change
      t.integer :change_type, null: false
      t.string :subject_role

      t.integer :scope_level, null: false
      t.string :service_id

      # 0: proposed / 1: approved / 2: in_effect / 3: rolled_back
      t.integer :status, default: 0, null: false

      t.text :rationale
      t.jsonb :diff, default: {}, null: false

      t.date :effective_from
      t.bigint :source_meeting_id
      t.bigint :source_ticket_id
      t.string :idempotency_key

      t.timestamps
    end

    add_index :org_change_ledgers, [ :change_type, :status ]
    add_index :org_change_ledgers, :source_meeting_id
    add_index :org_change_ledgers, :source_ticket_id
    add_index :org_change_ledgers, :idempotency_key, unique: true, where: "(idempotency_key IS NOT NULL)"
  end
end
