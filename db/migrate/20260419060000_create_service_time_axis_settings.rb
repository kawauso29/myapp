# Phase 44a / §11.3.3: 圧縮時間軸の DB 化。
# サービス毎に異なる圧縮率をサポートするためのテーブル。
# 未登録の cadence は `Ledgers::TimeAxis::INTERVALS` のデフォルト定数にフォールバックする。
class CreateServiceTimeAxisSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :service_time_axis_settings do |t|
      t.string  :service_id,       null: false
      t.integer :cadence,          null: false  # enum: daily/weekly/monthly/quarterly/annual/long_term
      t.integer :interval_seconds, null: false  # 圧縮 interval（秒）
      t.text    :description                    # 運用メモ（任意）

      t.timestamps
    end

    add_index :service_time_axis_settings, %i[service_id cadence], unique: true,
              name: "idx_stas_service_cadence"
  end
end
