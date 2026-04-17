require "rails_helper"

RSpec.describe "Admin::Ops::Knowledge", type: :request do
  let!(:adr) do
    KnowledgeLedger.create!(
      kind: :adr,
      status: :accepted,
      title: "ADR-001 Adopt Ruby 3.3",
      body: "...",
      tags: { service_id: "ai_sns" }
    )
  end
  let!(:runbook) do
    KnowledgeLedger.create!(
      kind: :runbook,
      status: :draft,
      title: "Puma Restart Runbook",
      body: "...",
      tags: { service_id: "ai_sns" }
    )
  end

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_PASSWORD").and_return("secret")
  end

  describe "GET /admin/ops/knowledge" do
    it "renders knowledge records and kind distribution" do
      get "/admin/ops/knowledge", headers: basic_auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Knowledge Ledger Viewer")
      expect(response.body).to include("ADR-001 Adopt Ruby 3.3")
      expect(response.body).to include("Puma Restart Runbook")
    end

    it "filters by kind" do
      get "/admin/ops/knowledge", params: { kind: "adr" }, headers: basic_auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("ADR-001 Adopt Ruby 3.3")
      expect(response.body).not_to include("Puma Restart Runbook")
    end
  end

  def basic_auth_headers
    { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials("ops", "secret") }
  end
end
