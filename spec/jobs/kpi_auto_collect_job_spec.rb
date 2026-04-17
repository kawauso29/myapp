require "rails_helper"

RSpec.describe KpiAutoCollectJob, type: :job do
  it "delegates to Reinforcements::KpiAutoCollector.call" do
    allow(Reinforcements::KpiAutoCollector).to receive(:call).and_return({ updated: 0, skipped: 0 })
    described_class.new.perform
    expect(Reinforcements::KpiAutoCollector).to have_received(:call)
  end
end
