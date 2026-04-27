class EnableUiCheckLedgerRunSchedule < ActiveRecord::Migration[8.1]
  def up
    return unless table_exists?(:service_schedule_definitions)

    # ui_check_ledger_run が既存なら有効化、なければ新規作成する（冪等）
    record = ServiceScheduleDefinition.find_by(job_key: "ui_check_ledger_run")
    if record
      record.update_columns(enabled: true)
    else
      ServiceScheduleDefinition.create!(
        job_key: "ui_check_ledger_run",
        job_class: "UiCheckLedgerRunJob",
        cron: "0 4 */2 * *",
        queue: "default",
        service_id: "ai_sns",
        cadence: :quarterly,
        args: [],
        enabled: true,
        description: "Phase 42 / UI伴走管理: 2日周期で ui_check 会議を実行し stale_ui_check を防ぐ"
      )
    end
  end

  def down
    ServiceScheduleDefinition.where(job_key: "ui_check_ledger_run").update_all(enabled: false) if table_exists?(:service_schedule_definitions)
  end
end
