class AddSalesMetricsToLinestampPacks < ActiveRecord::Migration[8.1]
  def change
    change_table :linestamp_packs do |t|
      t.integer  :purchase_unit_size, null: false, default: 8,
                 comment: "LINE申請単位 8/24/40 のいずれか。今は 8 固定運用、将来用カラム"
      t.datetime :published_at,
                 comment: "LINE 審査承認 → 販売開始日。NULL なら未公開"
      t.integer  :sales_count, null: false, default: 0,
                 comment: "LINEクリエイターズマーケットからの販売数キャッシュ(手動 or 将来API同期)"
    end
    add_index :linestamp_packs, :published_at
    add_index :linestamp_packs, :sales_count
  end
end
