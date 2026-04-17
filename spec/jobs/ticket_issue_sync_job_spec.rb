require "rails_helper"

RSpec.describe TicketIssueSyncJob, type: :job do
  it "delegates to Reinforcements::TicketIssueSync.call" do
    allow(Reinforcements::TicketIssueSync).to receive(:call).and_return({ synced: 0, skipped: 0, failed: 0, details: {} })
    described_class.new.perform
    expect(Reinforcements::TicketIssueSync).to have_received(:call)
  end
end
