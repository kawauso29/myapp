require "rails_helper"

RSpec.describe Ledgers::TicketLedgerGithubIssueSyncer do
  describe ".call" do
    let!(:eligible_ticket) do
      create(:ticket_ledger, ticket_type: :improvement, status: :approved, service_id: "ai_sns", title: "Fix KPI drift")
    end
    let!(:ineligible_ticket) { create(:ticket_ledger, ticket_type: :operations, status: :approved) }

    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("GOVERNANCE_GITHUB_REPO", "kawauso29/myapp").and_return("kawauso29/myapp")
      allow(ENV).to receive(:fetch).with("GOVERNANCE_GITHUB_SYNC_DRY_RUN", "true").and_return("true")
      allow(ENV).to receive(:[]).with("GOVERNANCE_GITHUB_TOKEN").and_return(nil)
      allow(ENV).to receive(:[]).with("GITHUB_TOKEN").and_return(nil)
    end

    it "dry-run by default and does not write linkage" do
      result = described_class.call

      expect(result[:dry_run]).to be(true)
      expect(result[:eligible]).to eq(1)
      expect(result[:created]).to eq(1)
      expect(result[:skipped]).to eq(1)
      expect(result[:details]).to include(hash_including(ticket_id: eligible_ticket.id, action: "create_dry_run"))
      expect(result[:details]).to include(hash_including(ticket_id: ineligible_ticket.id, action: "skip_ineligible"))
      expect(eligible_ticket.reload.github_issue_number).to be_nil
    end

    it "creates issue and persists linkage when dry-run is false" do
      allow(ENV).to receive(:fetch).with("GOVERNANCE_GITHUB_SYNC_DRY_RUN", "true").and_return("false")
      allow(ENV).to receive(:[]).with("GOVERNANCE_GITHUB_TOKEN").and_return("token")

      response = instance_double(Net::HTTPCreated, code: "201", body: { number: 123, html_url: "https://github.com/kawauso29/myapp/issues/123" }.to_json)
      http = instance_double(Net::HTTP)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:open_timeout=)
      allow(http).to receive(:read_timeout=)
      allow(http).to receive(:request) do |request|
        body = JSON.parse(request.body)
        expect(body["title"]).to eq("[ai_sns] improvement: Fix KPI drift")
        expect(body["body"]).to include("## Ledger Metadata (DO NOT EDIT)")
        expect(body["body"]).to include("ticket_ledger_id: #{eligible_ticket.id}")
        expect(body["body"]).to include("github_repo: kawauso29/myapp")
        response
      end
      allow(Net::HTTP).to receive(:new).with("api.github.com", 443).and_return(http)

      result = described_class.call

      expect(result[:created]).to eq(1)
      expect(eligible_ticket.reload.github_issue_number).to eq(123)
      expect(eligible_ticket.github_issue_url).to eq("https://github.com/kawauso29/myapp/issues/123")
      expect(eligible_ticket.github_issue_sync_status).to eq("synced")
      expect(result[:details]).to include(hash_including(ticket_id: eligible_ticket.id, action: "create", issue_number: 123))
    end

    it "updates issue when github_issue_number already exists" do
      eligible_ticket.update!(github_issue_number: 7, github_issue_url: "https://github.com/kawauso29/myapp/issues/7")
      allow(ENV).to receive(:fetch).with("GOVERNANCE_GITHUB_SYNC_DRY_RUN", "true").and_return("false")
      allow(ENV).to receive(:[]).with("GOVERNANCE_GITHUB_TOKEN").and_return("token")

      response = instance_double(Net::HTTPOK, code: "200", body: { number: 7, html_url: "https://github.com/kawauso29/myapp/issues/7" }.to_json)
      http = instance_double(Net::HTTP)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:open_timeout=)
      allow(http).to receive(:read_timeout=)
      allow(http).to receive(:request) do |request|
        expect(request.path).to eq("/repos/kawauso29/myapp/issues/7")
        response
      end
      allow(Net::HTTP).to receive(:new).with("api.github.com", 443).and_return(http)

      result = described_class.call

      expect(result[:updated]).to eq(1)
      expect(result[:details]).to include(hash_including(ticket_id: eligible_ticket.id, action: "update", issue_number: 7))
    end
  end
end
