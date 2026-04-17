require "rails_helper"

RSpec.describe GithubMapping::LedgerSyncService do
  describe ".sync_ticket_to_issue" do
    it "skips when already synced" do
      ticket = create(:ticket_ledger, github_issue_number: 42)
      result = described_class.sync_ticket_to_issue(ticket)

      expect(result[:synced]).to be false
      expect(result[:skipped]).to be true
    end

    it "creates issue and updates ticket" do
      ticket = create(:ticket_ledger)
      allow(GithubIssueService).to receive(:create_issue).and_return({ "number" => 99 })

      result = described_class.sync_ticket_to_issue(ticket)

      expect(result[:synced]).to be true
      expect(result[:issue_number]).to eq(99)
      expect(ticket.reload.github_issue_number).to eq(99)
      expect(ticket.github_synced_at).to be_present
    end

    it "returns error when GitHub API fails" do
      ticket = create(:ticket_ledger)
      allow(GithubIssueService).to receive(:create_issue).and_return(nil)

      result = described_class.sync_ticket_to_issue(ticket)

      expect(result[:synced]).to be false
      expect(result[:error]).to be_present
    end
  end

  describe ".sync_ticket_to_pr" do
    it "skips when PR already synced" do
      ticket = create(:ticket_ledger, github_pr_number: 10)
      result = described_class.sync_ticket_to_pr(ticket)

      expect(result[:skipped]).to be true
    end

    it "creates PR and updates ticket" do
      ticket = create(:ticket_ledger)
      allow(GithubPrService).to receive(:create_pr).and_return({ "number" => 55 })

      result = described_class.sync_ticket_to_pr(ticket)

      expect(result[:synced]).to be true
      expect(result[:pr_number]).to eq(55)
      expect(ticket.reload.github_pr_number).to eq(55)
    end
  end
end
