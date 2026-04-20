require "rails_helper"

RSpec.describe "Admin::Ops::Ledgers", type: :request do
  let!(:weekly_definition) { create(:meeting_definition, meeting_key: "weekly_dept", scope_level: :service, service_id: "ai_sns") }
  let!(:monthly_definition) { create(:meeting_definition, meeting_key: "monthly_ops", scope_level: :company, service_id: nil) }
  let!(:quarterly_definition) do
    create(:meeting_definition, meeting_key: "quarterly_review", meeting_type: :quarterly_review, scope_level: :company, service_id: nil)
  end
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
  let!(:quarterly_meeting) do
    create(
      :meeting_ledger,
      meeting_definition: quarterly_definition,
      meeting_key: "quarterly_review",
      meeting_type: :quarterly_review,
      scope_level: :company,
      service_id: nil,
      status: :closed
    )
  end
  let!(:quarterly_ticket) do
    create(
      :ticket_ledger,
      ticket_type: "quarterly_review",
      source_meeting: quarterly_meeting,
      source_meeting_type: :quarterly,
      scope_level: :company,
      service_id: nil,
      linked_kpis: { meetings_held: 4, tickets_total: 7 },
      status: :approved
    )
  end
  let!(:improvement_ticket) do
    create(
      :ticket_ledger,
      ticket_type: :improvement,
      source_meeting: weekly_meeting,
      source_meeting_type: :weekly,
      scope_level: :company,
      service_id: nil,
      linked_kpis: { rule: "overdue_rate", value: "25%", threshold: "20%" },
      status: :waiting_review,
      assignee: "improvement_detector"
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

    it "認証ありでダッシュボードが表示される" do
      get "/admin/ops/ledgers", headers: basic_auth_headers

      expect(response).to have_http_status(:ok)
      # ダッシュボードタイトル
      expect(response.body).to include("Ledger Dashboard")
      # cadence カード
      expect(response.body).to include("weekly_dept")
      expect(response.body).to include("daily")
      # サービス概要（ai_sns サービスのミーティングが存在するため表示される）
      expect(response.body).to include("ai_sns")
      # アラート表示（overdue チケットが存在するため待ちレビュー or 期限超過が出る）
      expect(response.body).to include("待ちレビュー")
      expect(response.body).to include("improvement")
      # 最近の実行ログに monthly_ops の行が出る
      expect(response.body).to include("monthly_ops")
      expect(response.body).to include("quarterly_review")
    end

    it "meeting_key で絞込むと cadence 実行履歴とチケットが表示される" do
      get "/admin/ops/ledgers",
          params: { meeting_key: "weekly_dept" },
          headers: basic_auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("weekly_dept")
      expect(response.body).to include(weekly_ticket.id.to_s)
      expect(response.body).to include("overdue")
      expect(response.body).to include("Open improvements:")
      expect(response.body).to include("improvement")
      expect(response.body).to include(improvement_ticket.id.to_s)
      # monthly_ops のチケットはチケットテーブルに出ない
      ticket_ids = extract_ticket_table_ids(response.body)
      expect(ticket_ids).not_to include(monthly_ticket.id.to_s)
    end

    it "service_id と meeting_key で絞り込みできる" do
      get "/admin/ops/ledgers",
          params: { service_id: "ai_sns", meeting_key: "weekly_dept" },
          headers: basic_auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("weekly_dept")
      expect(response.body).not_to include("monthly_ops 実行履歴")

      ticket_ids = extract_ticket_table_ids(response.body)
      expect(ticket_ids).to include(weekly_ticket.id.to_s)
      expect(ticket_ids).not_to include(monthly_ticket.id.to_s)
    end

    it "show で MeetingLedger 詳細が表示される" do
      get "/admin/ops/ledgers/#{weekly_meeting.id}", headers: basic_auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("weekly_dept")
      expect(response.body).to include(weekly_meeting.id.to_s)
      expect(response.body).to include("hold_items")
      expect(response.body).to include(weekly_ticket.id.to_s)
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
