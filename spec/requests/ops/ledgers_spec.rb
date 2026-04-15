require "rails_helper"

RSpec.describe "Ops::Ledgers", type: :request do
  let!(:weekly_definition) { create(:meeting_definition, meeting_key: "weekly_dept", scope_level: :service, service_id: "ai_sns") }
  let!(:monthly_definition) { create(:meeting_definition, meeting_key: "monthly_ops", scope_level: :company, service_id: nil) }
  let!(:weekly_meeting) do
    create(
      :meeting_ledger,
      meeting_definition: weekly_definition,
      meeting_key: "weekly_dept",
      service_id: "ai_sns",
      hold_items: [ { reason: "missing_kpi_definition", missing_kpi_keys: [ "kpi:risk" ] } ],
      status: :closed
    )
  end
  let!(:monthly_meeting) do
    create(
      :meeting_ledger,
      meeting_definition: monthly_definition,
      meeting_key: "monthly_ops",
      service_id: nil,
      hold_items: [],
      status: :closed
    )
  end
  let!(:weekly_ticket) { create(:ticket_ledger, source_meeting: weekly_meeting, service_id: "ai_sns", status: :waiting_review) }
  let!(:monthly_ticket) { create(:ticket_ledger, source_meeting: monthly_meeting, service_id: "trade_ops", status: :approved) }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_PASSWORD").and_return("secret")
  end

  describe "GET /ops/ledgers" do
    it "認証なしでは 401 を返す" do
      get "/ops/ledgers"

      expect(response).to have_http_status(:unauthorized)
    end

    it "認証ありで台帳一覧が表示される" do
      get "/ops/ledgers", headers: basic_auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Ops Ledger Viewer (Read Only)")
      expect(response.body).to include("weekly_dept")
      expect(response.body).to include(weekly_ticket.id.to_s)
      expect(response.body).to include(weekly_ticket.status)
    end

    it "service_id と meeting_key で絞り込みできる" do
      get "/ops/ledgers",
          params: { service_id: "ai_sns", meeting_key: "weekly_dept" },
          headers: basic_auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("weekly_dept")
      expect(response.body).not_to include("monthly_ops")
      expect(response.body).to include(weekly_ticket.id.to_s)
      expect(response.body).not_to include(monthly_ticket.id.to_s)
    end
  end

  def basic_auth_headers
    {
      "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials("ops", "secret")
    }
  end
end
