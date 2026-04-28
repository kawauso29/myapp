# ledger_v2_reviews — 人間レビューの履歴を記録する。
# 設計の正本: ledger_v2_detailed_design.txt §「ledger_v2_reviews」
#
# 重要ルール:
# - Review は履歴として残す（イミュータブル）
# - Artifact / Ticket / StopCondition の現在状態は別途更新する
# - 誰が何を判断したか追えるようにする
class CreateLedgerV2Reviews < ActiveRecord::Migration[8.1]
  def change
    create_table :ledger_v2_reviews, if_not_exists: true do |t|
      # polymorphic 対象: LedgerV2::Ticket / LedgerV2::Artifact / LedgerV2::StopCondition
      t.string  :reviewable_type, null: false
      t.bigint  :reviewable_id,   null: false

      # reviewer: 通常 User だが、システム自動レビューの場合もあるため type 許容
      t.string  :reviewer_type
      t.bigint  :reviewer_id

      # decision: accepted / rejected / deferred / needs_more_info / edited / cancelled
      t.string   :decision, null: false

      t.text     :comment
      t.datetime :reviewed_at, null: false

      t.jsonb :metadata_json

      t.timestamps
    end

    add_index :ledger_v2_reviews, [:reviewable_type, :reviewable_id],
              name: "index_ledger_v2_reviews_on_reviewable",
              if_not_exists: true
    add_index :ledger_v2_reviews, [:reviewer_type, :reviewer_id],
              name: "index_ledger_v2_reviews_on_reviewer",
              if_not_exists: true
    add_index :ledger_v2_reviews, :decision,    if_not_exists: true
    add_index :ledger_v2_reviews, :reviewed_at, if_not_exists: true
  end
end
