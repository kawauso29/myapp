# ledger_v2_tickets — 改善対象・異常・課題を表す台帳。
# 設計の正本: ledger_v2_detailed_design.txt §「ledger_v2_tickets」
#
# canonical_key の部分 unique index（partial unique index）:
#   open / in_progress / deferred 状態の canonical_key は一意にする。
#   resolved / rejected / duplicate / archived は再起票を許可する。
class CreateLedgerV2Tickets < ActiveRecord::Migration[8.1]
  def change
    create_table :ledger_v2_tickets, if_not_exists: true do |t|
      # 意味的重複を防ぐキー。自動起票は必ずこれを設定する（運用ルール §6）
      t.string  :canonical_key, null: false

      t.string  :title,        null: false
      t.text    :description

      # status: open / in_progress / deferred / resolved / rejected / duplicate / archived
      t.integer :status,       null: false, default: 0
      # severity: low / medium / high / critical
      t.integer :severity,     null: false, default: 1

      # 起票元の識別（どの種別・IDから生まれたか）
      t.string  :source_type
      t.string  :source_id

      # 異常検知メタデータ
      t.string  :metric_name
      t.string  :anomaly_type
      t.string  :period_bucket

      # 重複管理
      t.bigint  :duplicate_of_id
      t.bigint  :previous_ticket_id

      # Run との紐づき（RunExecutor 経由の制約）
      t.bigint  :opened_by_run_id
      t.bigint  :closed_by_run_id

      # 人間レビュー
      # review_status: not_required / pending / accepted / rejected / deferred / needs_more_info
      t.integer :review_status,   null: false, default: 0
      # human_decision: none / accepted / rejected / deferred / edited
      t.integer :human_decision,  null: false, default: 0
      t.text    :rejected_reason

      t.datetime :resolved_at
      t.datetime :due_at

      t.jsonb :metadata_json

      t.timestamps
    end

    # 頻繁に絞り込まれるカラムへの index
    add_index :ledger_v2_tickets, :status,                                 if_not_exists: true
    add_index :ledger_v2_tickets, :severity,                               if_not_exists: true
    add_index :ledger_v2_tickets, :opened_by_run_id,                       if_not_exists: true
    add_index :ledger_v2_tickets, :closed_by_run_id,                       if_not_exists: true
    add_index :ledger_v2_tickets, :source_type,                            if_not_exists: true
    add_index :ledger_v2_tickets, [:source_type, :source_id],              if_not_exists: true

    # 重複管理用 index
    add_index :ledger_v2_tickets, :duplicate_of_id,                        if_not_exists: true
    add_index :ledger_v2_tickets, :previous_ticket_id,                     if_not_exists: true

    # 部分 unique index: open / in_progress / deferred 状態の canonical_key は一意にする。
    # resolved / rejected / duplicate / archived 後の再起票は許可する。
    add_index :ledger_v2_tickets, :canonical_key,
              unique: true,
              where: "status IN (0, 1, 2)",
              name: "index_ledger_v2_tickets_on_canonical_key_active",
              if_not_exists: true
  end
end
