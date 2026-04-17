require "rails_helper"

RSpec.describe GithubMapping::ProjectFieldMapper do
  describe ".map" do
    it "maps ticket fields to GitHub Project field set" do
      ticket = create(:ticket_ledger, service_id: "ai_sns", priority: :high)
      result = described_class.map(ticket)

      expect(result[:scope_level]).to eq("service")
      expect(result[:service_id]).to eq("ai_sns")
      expect(result[:ticket_type]).to eq("operations")
      expect(result[:priority]).to eq("high")
      expect(result[:status]).to eq("draft")
    end
  end
end
