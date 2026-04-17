class CreateKnowledgeLedgers < ActiveRecord::Migration[8.1]
  # Phase 37 / §20: 知識台帳（ADR / Runbook / Incident / Deploy 記録）。
  #
  # PR ガードレール（Knowledge::PrGuardrail）は `high` リスクの improvement / incident 起票に
  # 対応する ADR または Runbook が存在することを要求する。
  def change
    create_table :knowledge_ledgers do |t|
      # 0: adr / 1: runbook / 2: incident / 3: deploy
      t.integer :kind, null: false

      t.string :title, null: false
      t.text :body, null: false, default: ""

      # ADR の判定（accepted / rejected / superseded 等）
      t.integer :status, default: 0, null: false # 0: draft / 1: accepted / 2: superseded / 3: archived

      t.bigint :supersedes_id
      t.bigint :source_meeting_id
      t.bigint :source_ticket_id

      # PR ガード用: 対応 ticket を拾うためのタグ（linked_services / linked_kpis 等）
      t.jsonb :tags, default: {}, null: false

      t.string :author
      t.string :idempotency_key

      t.datetime :accepted_at
      t.timestamps
    end

    add_index :knowledge_ledgers, [ :kind, :status ]
    add_index :knowledge_ledgers, :supersedes_id
    add_index :knowledge_ledgers, :source_meeting_id
    add_index :knowledge_ledgers, :source_ticket_id
    add_index :knowledge_ledgers, :idempotency_key, unique: true, where: "(idempotency_key IS NOT NULL)"
  end
end
