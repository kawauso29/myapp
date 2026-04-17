require "rails_helper"

RSpec.describe GithubMapping::PrBuilder do
  describe ".build" do
    it "builds PR payload with §31 mandatory fields" do
      ticket = create(:ticket_ledger, title: "Add feature X",
                      service_id: "ai_sns", risk_level: :medium)
      result = described_class.build(ticket, docs_update_required: true)

      expect(result[:title]).to include("ai_sns")
      expect(result[:title]).to include("Add feature X")
      expect(result[:body]).to include("service_id")
      expect(result[:body]).to include("linked_kpis")
      expect(result[:body]).to include("source_ticket_id")
      expect(result[:body]).to include("risk_level")
      expect(result[:body]).to include("docs_update_required | true")
      expect(result[:labels]).to include("risk:medium")
    end
  end
end
