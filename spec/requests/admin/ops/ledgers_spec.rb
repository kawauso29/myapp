require "rails_helper"

RSpec.describe "Admin::Ops::Ledgers", type: :request do
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
  let!(:weekly_ticket) do
    create(
      :ticket_ledger,
      source_meeting: weekly_meeting,
      service_id: "ai_sns",
      status: :overdue,
      assignee: "ai_sns",
      due_date: Date.current - 1.day
    )
  end
  let!(:monthly_ticket) do
    create(
      :ticket_ledger,
      source_meeting: monthly_meeting,
      service_id: "trade_ops",
      status: :approved,
      assignee: "monthly_ops_runner",
      due_date: Date.current + 30.days,
      resolved_at: Time.current
    )
  end

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_PASSWORD").and_return("secret")
  end

  describe "GET /admin/ops/ledgers" do
    it "認証なしでは 401 を返す" do
      get "/admin/ops/ledgers"

      expect(response).to have_http_status(:unauthorized)
    end

    it "認証ありで台帳一覧が表示される" do
      get "/admin/ops/ledgers", headers: basic_auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Ops Ledger Viewer (Read Only)")
      expect(response.body).to include("weekly_dept")
      expect(response.body).to include(weekly_ticket.id.to_s)
      expect(response.body).to include("overdue")
      expect(response.body).to include("monthly_ops_runner")
    end

    it "service_id と meeting_key で絞り込みできる" do
      get "/admin/ops/ledgers",
          params: { service_id: "ai_sns", meeting_key: "weekly_dept" },
          headers: basic_auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("weekly_dept")
      expect(response.body).not_to include("monthly_ops")

      ticket_ids = extract_ticket_table_ids(response.body)
      expect(ticket_ids).to include(weekly_ticket.id.to_s)
      expect(ticket_ids).not_to include(monthly_ticket.id.to_s)
    end
  end

  def basic_auth_headers
    {
      "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials("ops", "secret")
    }
  end

  def extract_ticket_table_ids(html)
    document = Nokogiri::HTML(html)
    document.css("div.card table tbody").last.css("tr td:first-child").map { |cell| cell.text.strip }
  end
end
