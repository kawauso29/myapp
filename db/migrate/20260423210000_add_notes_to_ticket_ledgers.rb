class AddNotesToTicketLedgers < ActiveRecord::Migration[8.1]
  # PR4（最終整理）: AI SNS 計画項目の `notes` を TicketLedger 側で正規化する。
  # PR3 までは TicketLedger に notes 列が無かったため、`Ledgers::AiSnsPlanSync.create_plan_item!`
  # は後方互換目的で DevInitiative 側に notes を逃がしていた。本 PR で TicketLedger に
  # notes 列を追加し、DevInitiative への退避を不要にする。
  #
  # nullable（既存の Runner 起票チケット等には notes が無いため）。
  # 自由記述 Markdown を想定するため text 型を採用。
  def change
    add_column :ticket_ledgers, :notes, :text unless column_exists?(:ticket_ledgers, :notes)
  end
end
