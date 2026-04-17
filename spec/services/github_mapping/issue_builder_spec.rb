require "rails_helper"

RSpec.describe GithubMapping::IssueBuilder do
  describe ".build" do
    it "builds Issue payload with required fields from ticket_ledger" do
      ticket = create(:ticket_ledger, title: "Fix AI response time",
                      service_id: "ai_sns", priority: :high)
      result = described_class.build(ticket)

      expect(result[:title]).to include("Fix AI response time")
      expect(result[:title]).to include("[operations]")
      expect(result[:body]).to include("ticket_id")
      expect(result[:body]).to include("ai_sns")
      expect(result[:labels]).to include("ledger:operations")
      expect(result[:labels]).to include("priority:high")
      expect(result[:labels]).to include("service:ai_sns")
    end

    it "includes scope and risk labels" do
      ticket = create(:ticket_ledger, scope_level: :company, risk_level: :high)
      result = described_class.build(ticket)

      expect(result[:labels]).to include("scope:company")
      expect(result[:labels]).to include("risk:high")
    end
  end
end
