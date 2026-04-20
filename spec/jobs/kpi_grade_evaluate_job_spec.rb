require "rails_helper"

RSpec.describe KpiGradeEvaluateJob, type: :job do
  it "delegates to Reinforcements::KpiGradeEvaluator.call" do
    allow(Reinforcements::KpiGradeEvaluator).to receive(:call).and_return({ evaluated: 0, skipped: 0, details: [] })
    described_class.new.perform
    expect(Reinforcements::KpiGradeEvaluator).to have_received(:call)
  end
end
