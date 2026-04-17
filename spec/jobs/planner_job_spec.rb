require "rails_helper"

RSpec.describe PlannerJob, type: :job do
  it "delegates to Reinforcements::Planner.call" do
    allow(Reinforcements::Planner).to receive(:call).and_return({ created: 0, skipped: 0, details: {} })
    described_class.new.perform
    expect(Reinforcements::Planner).to have_received(:call)
  end
end
