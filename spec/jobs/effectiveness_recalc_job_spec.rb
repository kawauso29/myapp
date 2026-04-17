require "rails_helper"

RSpec.describe EffectivenessRecalcJob, type: :job do
  it "delegates to Reinforcements::EffectivenessRecalculator.call" do
    allow(Reinforcements::EffectivenessRecalculator).to receive(:call).and_return({ processed: 0, updated: 0 })
    described_class.new.perform
    expect(Reinforcements::EffectivenessRecalculator).to have_received(:call)
  end
end
