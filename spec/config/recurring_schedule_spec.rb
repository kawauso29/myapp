require "spec_helper"
require "yaml"

RSpec.describe "recurring schedule config" do
  let(:config) do
    YAML.safe_load_file(
      File.expand_path("../../config/recurring.yml", __dir__),
      symbolize_names: true
    )
  end

  it "runs picro_check every 15 minutes in production" do
    expect(config.dig(:production, :picro_check, :class)).to eq("PicroCheckJob")
    expect(config.dig(:production, :picro_check, :schedule)).to eq("*/15 * * * *")
  end

  it "clears SolidQueue finished jobs every hour" do
    entry = config.dig(:production, :clear_solid_queue_finished_jobs)
    expect(entry[:command]).to include("clear_finished_in_batches")
    expect(entry[:schedule]).to eq("every hour at minute 12")
  end
end
