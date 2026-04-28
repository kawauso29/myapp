# ledger_v2_metric_snapshots — KPI・システム指標のスナップショットを保存する。
# 設計の正本: ledger_v2_detailed_design.txt §「ledger_v2_metric_snapshots」
#
# 重要ルール:
# - Snapshot は観測事実として保存する（判断は Event / Ticket に分ける）
# - Snapshot 作成だけでは Ticket を作らない
# - 異常検知サービスが Snapshot を読んで Ticket 候補を作る（Ticket 9 で実装）
class CreateLedgerV2MetricSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :ledger_v2_metric_snapshots, if_not_exists: true do |t|
      # 指標の名前（例: ai_sns_posts_count, ci_success_rate）
      t.string   :metric_name, null: false

      # 観測対象（何のデータか）
      t.string   :source_type
      t.string   :source_id

      # 計測値
      t.decimal  :value,    null: false, precision: 20, scale: 6
      t.string   :unit

      # 集計粒度: hourly / daily / weekly
      t.integer  :period,       null: false, default: 0

      # 実際に計測した日時（created_at とは別に保持する）
      t.datetime :measured_at,  null: false

      # 追加の構造化データ（任意）
      t.jsonb    :payload_json

      # 作成元の Run（RunExecutor 経由の制約を記録する）
      t.bigint   :created_by_run_id

      t.timestamps
    end

    add_index :ledger_v2_metric_snapshots, :metric_name,        if_not_exists: true
    add_index :ledger_v2_metric_snapshots, :period,             if_not_exists: true
    add_index :ledger_v2_metric_snapshots, :measured_at,        if_not_exists: true
    add_index :ledger_v2_metric_snapshots, :created_by_run_id,  if_not_exists: true
    add_index :ledger_v2_metric_snapshots, [:source_type, :source_id], if_not_exists: true

    # 同一指標の同一集計期間での重複保存を防ぐ複合 index
    add_index :ledger_v2_metric_snapshots,
              [:metric_name, :source_type, :source_id, :period, :measured_at],
              name: "index_ledger_v2_metric_snapshots_on_key",
              if_not_exists: true
  end
end
