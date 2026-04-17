class AddOperatingLaneToTicketLedgers < ActiveRecord::Migration[8.1]
  # Phase 36 / §13: 28日運営レーン（4 レーン）の正規化。
  #
  # - immediate: 当日対応（障害・問い合わせ）
  # - weekly_improvement: 週次改善（7日以内）
  # - monthly_ops: 月次運営（28日以内）
  # - quarterly_review: 四半期以上
  def change
    add_column :ticket_ledgers, :operating_lane, :integer
    add_index :ticket_ledgers, [ :operating_lane, :status ], name: "idx_ticket_operating_lane_status"

    create_table :lane_capacity_caps do |t|
      # scope_level と service_id で絞り込み単位を決める（NULL = グローバル）
      t.integer :scope_level
      t.string :service_id

      # ticket_ledgers.operating_lane と同じ列挙値
      t.integer :operating_lane, null: false

      # そのレーンで同時に存在可能な waiting_review / approved / in_progress の上限
      t.integer :wip_cap, null: false, default: 5
      t.text :notes

      t.timestamps
    end

    add_index :lane_capacity_caps,
              [ :scope_level, :service_id, :operating_lane ],
              unique: true,
              name: "idx_lane_capacity_scope_lane"
  end
end
