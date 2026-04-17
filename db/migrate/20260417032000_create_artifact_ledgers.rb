class CreateArtifactLedgers < ActiveRecord::Migration[8.1]
  # Phase 31 / 補強4: §16 で規定された 6 成果物（KPI定義書 / 仕様書 / 実行計画書 / 監査判定書 /
  # 顧客案内 / 技術記録）を台帳化する。
  #
  # バージョン管理は `artifact_version`（単調増加整数）と `supersedes_id`（self-reference）で表現し、
  # 古い版も不可視ではなく `status: superseded` で台帳に残す（§16 成果物記録原則）。
  def change
    create_table :artifact_ledgers do |t|
      # 0: kpi_definition / 1: spec / 2: execution_plan /
      # 3: audit_judgment / 4: customer_notice / 5: tech_record
      t.integer :artifact_type, null: false

      # 0: company / 1: portfolio / 2: service / 3: cross_service
      t.integer :scope_level, null: false
      t.string :service_id

      t.string :title, null: false
      t.integer :artifact_version, null: false, default: 1
      t.jsonb :content, default: {}, null: false

      # 0: draft / 1: published / 2: superseded / 3: archived
      t.integer :status, null: false, default: 0

      t.bigint :supersedes_id
      t.bigint :source_meeting_id
      t.bigint :source_ticket_id

      t.string :author
      t.string :idempotency_key

      t.datetime :published_at
      t.timestamps
    end

    add_index :artifact_ledgers, [ :artifact_type, :scope_level, :service_id ], name: "idx_artifact_ledgers_type_scope"
    add_index :artifact_ledgers, :supersedes_id
    add_index :artifact_ledgers, :source_meeting_id
    add_index :artifact_ledgers, :source_ticket_id
    add_index :artifact_ledgers, :status
    add_index :artifact_ledgers, :idempotency_key, unique: true, where: "(idempotency_key IS NOT NULL)"
    add_index :artifact_ledgers, [ :artifact_type, :title, :artifact_version ], unique: true, name: "idx_artifact_ledgers_type_title_version"
  end
end
