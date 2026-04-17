require "rails_helper"

RSpec.describe "Admin::Ops::AuditDecisions", type: :request do
  let(:ticket) { create(:ticket_ledger, ticket_type: "audit") }
  let!(:approval) do
    AuditDecisionLedger.create!(
      target_ticket: ticket,
      decision: :approve,
      reason_code: "approved_no_reservation",
      audit_role: "audit_board",
      scope_level: :service,
      service_id: "ai_sns",
      decided_at: 1.day.ago
    )
  end
  let!(:rejection) do
    AuditDecisionLedger.create!(
      target_ticket: ticket,
      decision: :reject,
      reason_code: "security_risk",
      audit_role: "audit_board",
      scope_level: :service,
      service_id: "ai_sns",
      decided_at: 2.hours.ago
    )
  end

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_PASSWORD").and_return("secret")
  end

  describe "GET /admin/ops/audit_decisions" do
    it "returns 401 without auth" do
      get "/admin/ops/audit_decisions"
      expect(response).to have_http_status(:unauthorized)
    end

    it "renders decision distribution and non-approval section" do
      get "/admin/ops/audit_decisions", headers: basic_auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Audit Decisions Viewer")
      expect(response.body).to include("approved_no_reservation")
      expect(response.body).to include("security_risk")
      expect(response.body).to include("Non-approval")
    end

    it "filters by decision" do
      get "/admin/ops/audit_decisions", params: { decision: "reject" }, headers: basic_auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("security_risk")
    end
  end

  def basic_auth_headers
    { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials("ops", "secret") }
  end
end
