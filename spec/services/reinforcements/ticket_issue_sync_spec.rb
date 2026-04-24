require "rails_helper"

RSpec.describe Reinforcements::TicketIssueSync do
  describe ".call" do
    before do
      allow(GithubIssueService).to receive(:create_comment).and_return({ "id" => 1 })
      allow(GithubIssueService).to receive(:add_assignees).and_return({ "assignees" => [ { "login" => "copilot-swe-agent[bot]" } ] })
    end

    it "calls LedgerSyncService for approved / planned tickets without github_issue_number" do
      approved = create(:ticket_ledger, status: :approved)
      planned  = create(:ticket_ledger, status: :planned)
      draft    = create(:ticket_ledger, status: :draft)
      done     = create(:ticket_ledger, status: :completed)

      allow(GithubMapping::LedgerSyncService).to receive(:sync_ticket_to_issue) do |t|
        { synced: true, issue_number: 1000 + t.id }
      end

      result = described_class.call

      expect(result[:synced]).to eq(2)
      expect(GithubMapping::LedgerSyncService).to have_received(:sync_ticket_to_issue).with(approved)
      expect(GithubMapping::LedgerSyncService).to have_received(:sync_ticket_to_issue).with(planned)
      expect(GithubMapping::LedgerSyncService).not_to have_received(:sync_ticket_to_issue).with(draft)
      expect(GithubMapping::LedgerSyncService).not_to have_received(:sync_ticket_to_issue).with(done)
    end

    it "posts @copilot comment after Issue creation for improvement ticket" do
      ticket = create(:ticket_ledger, status: :approved, ticket_type: :improvement)
      allow(GithubMapping::LedgerSyncService).to receive(:sync_ticket_to_issue)
        .and_return({ synced: true, issue_number: 999 })

      result = described_class.call

      expect(result[:copilot_triggered]).to eq(1)
      # コメントを先に投稿してから Copilot をアサインする順序を確認
      expect(GithubIssueService).to have_received(:create_comment).with(
        issue_number: 999,
        body: include("@copilot")
      )
      expect(GithubIssueService).to have_received(:add_assignees).with(
        issue_number: 999,
        assignees: [ GithubIssueService::COPILOT_AGENT_LOGIN ],
        agent_assignment: hash_including(
          target_repo: GithubIssueService::REPO,
          base_branch: "main"
        )
      )
    end

    it "posts @copilot comment for operations ticket with non-default title" do
      ticket = create(:ticket_ledger, status: :approved, ticket_type: :operations)
      allow(GithubMapping::LedgerSyncService).to receive(:sync_ticket_to_issue)
        .and_return({ synced: true, issue_number: 999 })

      result = described_class.call

      expect(result[:copilot_triggered]).to eq(1)
    end

    it "does NOT post @copilot comment for quarterly_review tickets" do
      create(:ticket_ledger, status: :approved, ticket_type: :quarterly_review, scope_level: :company, service_id: nil)
      allow(GithubMapping::LedgerSyncService).to receive(:sync_ticket_to_issue)
        .and_return({ synced: true, issue_number: 999 })

      result = described_class.call

      expect(result[:copilot_triggered]).to eq(0)
      expect(GithubIssueService).not_to have_received(:create_comment)
      expect(GithubIssueService).not_to have_received(:add_assignees)
    end

    it "does NOT post @copilot comment for annual_plan tickets" do
      create(:ticket_ledger, status: :approved, ticket_type: :annual_plan, scope_level: :company, service_id: nil)
      allow(GithubMapping::LedgerSyncService).to receive(:sync_ticket_to_issue)
        .and_return({ synced: true, issue_number: 999 })

      result = described_class.call

      expect(result[:copilot_triggered]).to eq(0)
      expect(GithubIssueService).not_to have_received(:create_comment)
      expect(GithubIssueService).not_to have_received(:add_assignees)
    end

    it "does NOT post @copilot comment for operations default placeholder tickets" do
      create(:ticket_ledger, status: :approved, ticket_type: :operations, title: "weekly_dept default ticket for ai_sns")
      allow(GithubMapping::LedgerSyncService).to receive(:sync_ticket_to_issue)
        .and_return({ synced: true, issue_number: 999 })

      result = described_class.call

      expect(result[:copilot_triggered]).to eq(0)
      expect(GithubIssueService).not_to have_received(:create_comment)
      expect(GithubIssueService).not_to have_received(:add_assignees)
    end

    it "includes ticket_ledger id in @copilot comment branch hint" do
      ticket = create(:ticket_ledger, status: :approved, ticket_type: :improvement)
      allow(GithubMapping::LedgerSyncService).to receive(:sync_ticket_to_issue)
        .and_return({ synced: true, issue_number: 999 })

      described_class.call

      expect(GithubIssueService).to have_received(:create_comment).with(
        issue_number: 999,
        body: include("copilot/ledger-#{ticket.id}")
      )
    end

    it "skips tickets that already have github_issue_number" do
      ticket = create(:ticket_ledger, status: :approved)
      ticket.update_columns(github_issue_number: 42)

      allow(GithubMapping::LedgerSyncService).to receive(:sync_ticket_to_issue).and_return({ synced: false, skipped: true, reason: "already synced" })

      described_class.call

      expect(GithubMapping::LedgerSyncService).not_to have_received(:sync_ticket_to_issue)
    end

    it "counts failures separately" do
      create(:ticket_ledger, status: :approved)
      allow(GithubMapping::LedgerSyncService).to receive(:sync_ticket_to_issue).and_return({ synced: false, error: "boom" })

      result = described_class.call
      expect(result[:failed]).to eq(1)
      expect(result[:synced]).to eq(0)
    end

    it "does not count copilot_triggered when comment post fails" do
      create(:ticket_ledger, status: :approved, ticket_type: :improvement)
      allow(GithubMapping::LedgerSyncService).to receive(:sync_ticket_to_issue)
        .and_return({ synced: true, issue_number: 999 })
      allow(GithubIssueService).to receive(:create_comment).and_return(nil)

      result = described_class.call
      expect(result[:synced]).to eq(1)
      expect(result[:copilot_triggered]).to eq(0)
    end

    it "respects MAX_PER_RUN limit" do
      stub_const("Reinforcements::TicketIssueSync::MAX_PER_RUN", 2)
      3.times { create(:ticket_ledger, status: :approved) }
      allow(GithubMapping::LedgerSyncService).to receive(:sync_ticket_to_issue).and_return({ synced: true, issue_number: 1 })

      result = described_class.call
      expect(result[:synced]).to eq(2)
    end
  end
end
