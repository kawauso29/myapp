require "spec_helper"
require "yaml"

RSpec.describe "recurring schedule config" do
  it "runs hourly_state_update every 30 minutes in production" do
    config = YAML.safe_load_file(
      File.expand_path("../../config/recurring.yml", __dir__),
      symbolize_names: true
    )

    expect(config.dig(:production, :hourly_state_update, :class)).to eq("HourlyStateUpdateJob")
    expect(config.dig(:production, :hourly_state_update, :schedule)).to eq("*/30 * * * *")
  end

  it "includes ops ledger recurring schedules in production" do
    config = YAML.safe_load_file(
      File.expand_path("../../config/recurring.yml", __dir__),
      symbolize_names: true
    )

    expect(config.dig(:production, :weekly_dept_ledger_run, :class)).to eq("WeeklyDeptLedgerRunJob")
    expect(config.dig(:production, :weekly_dept_ledger_run, :args)).to eq([ "ai_sns" ])
    expect(config.dig(:production, :weekly_dept_ledger_run, :schedule)).to eq("0 */4 * * *")

    expect(config.dig(:production, :monthly_ops_ledger_run, :class)).to eq("MonthlyOpsLedgerRunJob")
    expect(config.dig(:production, :monthly_ops_ledger_run, :schedule)).to eq("0 */12 * * *")

    expect(config.dig(:production, :ticket_overdue_check, :class)).to eq("TicketOverdueCheckJob")
    expect(config.dig(:production, :ticket_overdue_check, :schedule)).to eq("0 21 * * *")
  end

  it "includes ui_check_ledger_run schedule in production" do
    config = YAML.safe_load_file(
      File.expand_path("../../config/recurring.yml", __dir__),
      symbolize_names: true
    )

    expect(config.dig(:production, :ui_check_ledger_run, :class)).to eq("UiCheckLedgerRunJob")
    expect(config.dig(:production, :ui_check_ledger_run, :schedule)).to eq("0 4 */2 * *")
  end
end
