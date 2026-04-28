# ledger_v2_artifacts — Runner が生成した成果物・レビュー文書・改善提案を保存する。
# 設計の正本: ledger_v2_detailed_design.txt §「ledger_v2_artifacts」
#
# 重要ルール:
# - Runner が作る Artifact は原則 draft または pending（人間承認なしに published にしない）
# - 1 つの Artifact は Run および/または Ticket に紐づく
class CreateLedgerV2Artifacts < ActiveRecord::Migration[8.1]
  def change
    create_table :ledger_v2_artifacts, if_not_exists: true do |t|
      # 起票元の Run / 関連 Ticket
      t.bigint  :run_id
      t.bigint  :related_ticket_id

      # artifact_type: daily_summary / weekly_review / improvement_proposal /
      #                anomaly_report / health_report / manual_review_note
      t.string  :artifact_type, null: false

      t.string  :title,         null: false
      t.text    :body

      # format: markdown / text / json / html
      t.string  :format,        null: false, default: "markdown"

      # review_status: draft / pending / accepted / rejected / deferred /
      #                needs_more_info / published
      t.integer :review_status, null: false, default: 0

      t.string   :reviewed_by
      t.datetime :reviewed_at
      t.text     :review_comment
      t.datetime :published_at

      t.jsonb :metadata_json

      t.timestamps
    end

    add_index :ledger_v2_artifacts, :run_id,             if_not_exists: true
    add_index :ledger_v2_artifacts, :related_ticket_id,  if_not_exists: true
    add_index :ledger_v2_artifacts, :artifact_type,      if_not_exists: true
    add_index :ledger_v2_artifacts, :review_status,      if_not_exists: true
    add_index :ledger_v2_artifacts, :published_at,       if_not_exists: true
  end
end
