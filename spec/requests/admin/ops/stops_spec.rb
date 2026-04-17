require "rails_helper"

RSpec.describe "Admin::Ops::Stops", type: :request do
  let!(:active_stop) do
    create(:stop_ledger,
           trigger_type: :kpi_breach,
           trigger_detail: "wau dropped",
           service_id: "ai_sns",
           status: :active,
           started_at: 1.hour.ago,
           evidence: { kpi_key: "wau" })
  end
  let!(:lifted_stop) do
    create(:stop_ledger,
           trigger_type: :cost_runaway,
           trigger_detail: "cost spike",
           service_id: "ai_sns",
           status: :lifted,
           started_at: 1.day.ago,
           lifted_at: 1.hour.ago,
           lifted_by: "operator@example.com",
           lift_reason: "resolved")
  end

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_PASSWORD").and_return("secret")
  end

  describe "GET /admin/ops/stops" do
    it "renders active count and trigger distribution" do
      get "/admin/ops/stops", headers: basic_auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Stop Ledger Viewer")
      expect(response.body).to include("kpi_breach")
      expect(response.body).to include("cost_runaway")
    end
  end

  describe "POST /admin/ops/stops/:id/lift" do
    it "lifts active stop with reason" do
      expect {
        post "/admin/ops/stops/#{active_stop.id}/lift",
             params: { lift_reason: "kpi recovered", lifted_by: "operator@example.com" },
             headers: basic_auth_headers
      }.to change { active_stop.reload.status }.from("active").to("lifted")

      expect(active_stop.lifted_by).to eq("operator@example.com")
      expect(active_stop.lift_reason).to eq("kpi recovered")
      expect(response).to redirect_to(admin_ops_stops_path)
    end

    it "rejects lift without reason" do
      post "/admin/ops/stops/#{active_stop.id}/lift",
           params: { lift_reason: "" },
           headers: basic_auth_headers

      expect(active_stop.reload.status).to eq("active")
      expect(flash[:alert]).to include("lift_reason は必須")
    end

    it "rejects lift for non-active stop" do
      post "/admin/ops/stops/#{lifted_stop.id}/lift",
           params: { lift_reason: "already done", lifted_by: "ops" },
           headers: basic_auth_headers

      expect(lifted_stop.reload.status).to eq("lifted")
      expect(flash[:alert]).to include("active ではない")
    end
  end

  def basic_auth_headers
    { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials("ops", "secret") }
  end
end
