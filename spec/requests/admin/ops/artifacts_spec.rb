require "rails_helper"

RSpec.describe "Admin::Ops::Artifacts", type: :request do
  let!(:artifact) do
    ArtifactLedger.create!(
      artifact_type: :spec,
      scope_level: :service,
      service_id: "ai_sns",
      title: "Service Spec v1",
      content: { description: "body" },
      status: :published,
      author: "system",
      published_at: Time.current,
      artifact_version: 1
    )
  end
  let!(:active_stop) do
    create(:stop_ledger,
           trigger_type: :kpi_breach,
           trigger_detail: "wau dropped",
           service_id: "ai_sns",
           status: :active,
           started_at: 1.hour.ago,
           evidence: { kpi_key: "wau" })
  end
  let!(:feedback) do
    create(:customer_feedback_ledger,
           source: :in_app,
           service_id: "ai_sns",
           raw_text: "The new UI is great",
           received_at: 10.minutes.ago)
  end

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_PASSWORD").and_return("secret")
  end

  describe "GET /admin/ops/artifacts" do
    it "returns 401 without auth" do
      get "/admin/ops/artifacts"

      expect(response).to have_http_status(:unauthorized)
    end

    it "renders artifacts, stops, and feedback" do
      get "/admin/ops/artifacts", headers: basic_auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Ops Artifacts / Stops / Feedback Viewer")
      expect(response.body).to include("Service Spec v1")
      expect(response.body).to include("kpi_breach")
      expect(response.body).to include("The new UI is great")
    end
  end

  def basic_auth_headers
    {
      "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials("ops", "secret")
    }
  end
end
