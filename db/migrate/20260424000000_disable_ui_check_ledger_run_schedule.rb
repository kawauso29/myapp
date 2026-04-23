class DisableUiCheckLedgerRunSchedule < ActiveRecord::Migration[8.1]
  def up
    ServiceScheduleDefinition.where(job_key: "ui_check_ledger_run").update_all(enabled: false) if table_exists?(:service_schedule_definitions)
  end

  def down
    ServiceScheduleDefinition.where(job_key: "ui_check_ledger_run").update_all(enabled: true) if table_exists?(:service_schedule_definitions)
  end
end
