require "rails_helper"

RSpec.describe KpiLedger, "#numeric_target_value" do
  it "returns target_value['value'] when set" do
    kpi = build(:kpi_ledger, target_value: { "value" => 1000 }, thresholds: { "healthy" => 500 })
    expect(kpi.numeric_target_value).to eq(1000.0)
  end

  it "falls back to thresholds['healthy'] when target_value is empty" do
    kpi = build(:kpi_ledger, target_value: {}, thresholds: { "healthy" => 500 })
    expect(kpi.numeric_target_value).to eq(500.0)
  end

  it "returns nil when neither is set" do
    kpi = build(:kpi_ledger, target_value: {}, thresholds: {})
    expect(kpi.numeric_target_value).to be_nil
  end

  it "handles raw numeric target_value (non-Hash)" do
    kpi = build(:kpi_ledger, target_value: { "value" => "200.5" }, thresholds: {})
    expect(kpi.numeric_target_value).to eq(200.5)
  end
end
