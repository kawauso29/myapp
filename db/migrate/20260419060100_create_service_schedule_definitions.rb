# Phase 44c / §12: recurring.yml のジョブ定義を DB 化し、
# サービス追加時に自動的にスケジュールが生成される仕組み。
class CreateServiceScheduleDefinitions < ActiveRecord::Migration[8.1]
  def change
    create_table :service_schedule_definitions do |t|
      t.string  :job_key,    null: false  # ユニークキー（例: "daily_ledger_run:ai_sns"）
      t.string  :job_class,  null: false  # ActiveJob クラス名
      t.string  :queue,      null: false, default: "default"
      t.string  :cron,       null: false  # cron 式
      t.string  :service_id               # サービス単位（nil = 全社）
      t.integer :cadence                  # enum: daily/weekly/monthly/quarterly/annual/long_term（任意）
      t.jsonb   :args,       null: false, default: [] # ジョブ引数
      t.boolean :enabled,    null: false, default: true
      t.text    :description              # 運用メモ（任意）

      t.timestamps
    end

    add_index :service_schedule_definitions, :job_key, unique: true
    add_index :service_schedule_definitions, :enabled
    add_index :service_schedule_definitions, :service_id
  end
end
