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

  # v1 Ledger Runner schedules are frozen (commented out in recurring.yml) during Ledger V2 migration.
  # These tests are skipped until V2 runners are re-enabled.
  it "v1 ops ledger recurring schedules are frozen during V2 migration" do
    config = YAML.safe_load_file(
      File.expand_path("../../config/recurring.yml", __dir__),
      symbolize_names: true
    )

    expect(config.dig(:production, :weekly_dept_ledger_run)).to be_nil
    expect(config.dig(:production, :monthly_ops_ledger_run)).to be_nil
    expect(config.dig(:production, :ticket_overdue_check)).to be_nil
    expect(config.dig(:production, :ui_check_ledger_run)).to be_nil
  end
end
