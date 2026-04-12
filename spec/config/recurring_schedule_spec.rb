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
end
