require "rails_helper"

RSpec.describe Linestamp::DailyOrchestratorJob, type: :job do
  let(:brand) { Linestamp::Brand.create!(slug: "test", character_name: "Test", series_name: "Test Series", status: "planned") }

  before do
    allow(Linestamp::SlackNotifier).to receive(:notify)
    ActiveJob::Base.queue_adapter = :test
  end

  it "enqueues compose jobs for planned brands" do
    brand

    expect {
      described_class.perform_now
    }.to have_enqueued_job(Linestamp::ComposeBrandPromptJob).with(brand.id)
  end
end
