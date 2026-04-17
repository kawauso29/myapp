require "rails_helper"

RSpec.describe ExperimentAutoDeciderJob, type: :job do
  it "delegates to Reinforcements::ExperimentAutoDecider.call" do
    allow(Reinforcements::ExperimentAutoDecider).to receive(:call).and_return({ decided: 0, details: [] })
    described_class.new.perform
    expect(Reinforcements::ExperimentAutoDecider).to have_received(:call)
  end
end
