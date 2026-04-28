# ledger_v2_stop_conditions — Runner / 自動化を止める条件を記録する。
# 設計の正本: ledger_v2_detailed_design.txt §「ledger_v2_stop_conditions」
class CreateLedgerV2StopConditions < ActiveRecord::Migration[8.1]
  def change
    create_table :ledger_v2_stop_conditions, if_not_exists: true do |t|
      # 何を止めるか（runner / feature / ticket_creation / artifact_generation / auto_pr / auto_merge / all）
      t.string   :target_type, null: false
      # 具体的な対象名（例: "DailyRunner", "WeeklyRunner"）。target_type: "all" の場合は nil 可
      t.string   :target_name

      t.text     :reason,     null: false
      t.string   :severity,   null: false, default: "medium"

      # active: true = 有効中（RunExecutor がこれを見てブロックする）
      t.boolean  :active,     null: false, default: true

      # 解除は人間のみ。AI による変更は禁止。
      t.string   :created_by, null: false
      t.string   :resolved_by
      t.datetime :resolved_at

      # expires_at を過ぎた場合は自動解除してよい（critical を除く）
      t.datetime :expires_at

      t.jsonb    :metadata_json

      t.timestamps
    end

    add_index :ledger_v2_stop_conditions, %i[target_type active],   if_not_exists: true
    add_index :ledger_v2_stop_conditions, %i[active expires_at],    if_not_exists: true
  end
end
