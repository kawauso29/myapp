class AddPhase30LedgerFoundations < ActiveRecord::Migration[8.0]
  # Phase 30: 台帳土台の完成
  #
  # 補強1: idempotency_key を meeting_ledgers / ticket_ledgers に追加し、
  #        同一イベントの二重書き込みを DB レベルで防ぐ。
  # 補強8: 会議引き継ぎ項目 carry_over_items を meeting_ledgers に追加する。
  #        既存の hold_items（会議内での保留）とは別で、次回会議サイクルへ
  #        持ち越す決定保留を明示的に記録する（§26.3 / §26.5）。
  def change
    # 補強1: idempotency_key（会議台帳）
    add_column :meeting_ledgers, :idempotency_key, :string
    add_index :meeting_ledgers,
              :idempotency_key,
              unique: true,
              where: "idempotency_key IS NOT NULL",
              name: "index_meeting_ledgers_on_idempotency_key"

    # 補強1: idempotency_key（起票台帳）
    add_column :ticket_ledgers, :idempotency_key, :string
    add_index :ticket_ledgers,
              :idempotency_key,
              unique: true,
              where: "idempotency_key IS NOT NULL",
              name: "index_ticket_ledgers_on_idempotency_key"

    # 補強8: 会議引き継ぎ項目
    add_column :meeting_ledgers, :carry_over_items, :jsonb, default: [], null: false
  end
end
