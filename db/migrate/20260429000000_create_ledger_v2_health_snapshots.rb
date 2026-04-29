class CreateLedgerV2HealthSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :ledger_v2_health_snapshots, if_not_exists: true do |t|
      # 集計粒度（0: daily, 1: weekly）
      t.integer  :period,                          null: false, default: 0
      # 集計基準時点
      t.datetime :measured_at,                     null: false

      # ---- 主要健全性指標 ----
      # 不要・却下されたTicketの割合（0.0〜1.0）
      t.float    :ticket_noise_rate,               null: false, default: 0.0
      # Artifactが承認・採用された割合（0.0〜1.0）
      t.float    :artifact_acceptance_rate,        null: false, default: 0.0
      # Runner実行失敗率（0.0〜1.0）
      t.float    :runner_failure_rate,             null: false, default: 0.0
      # 未解決Ticketの平均滞留時間（時間単位）
      t.float    :unresolved_ticket_age_avg,       null: false, default: 0.0
      # 人間が修正・却下・停止した割合（0.0〜1.0）
      t.float    :human_intervention_rate,         null: false, default: 0.0
      # Ticket起票後にKPIが改善した割合（0.0〜1.0）
      t.float    :kpi_improvement_after_ticket_rate, null: false, default: 0.0

      # ---- カウント系指標 ----
      # StopCondition / CircuitBreakerが発火した回数
      t.integer  :stop_trigger_count,              null: false, default: 0
      # 重複Ticketを防いだ回数（期間内のRunから集計）
      t.integer  :duplicate_prevented_count,       null: false, default: 0
      # レビュー待ちのArtifact / Ticket合計
      t.integer  :pending_review_count,            null: false, default: 0
      # アクティブ（open / in_progress / deferred）なTicket件数
      t.integer  :open_ticket_count,               null: false, default: 0

      # 補足情報（集計パラメータなど）
      t.jsonb    :metadata_json

      t.timestamps
    end

    add_index :ledger_v2_health_snapshots, %i[period measured_at],
              unique: true, if_not_exists: true,
              name: "idx_ledger_v2_health_snapshots_period_measured_at"
  end
end
