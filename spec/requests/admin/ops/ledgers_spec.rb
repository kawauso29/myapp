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
      service_id: "support_ops",
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
  let!(:planning_role) do
    OrganizationRole.find_or_create_by!(role_key: "planning") do |role|
      role.display_name = "Planning"
      role.scope_level = :service
      role.category = :department
      role.active = true
    end
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
  let!(:weekly_heartbeat) do
    create(
      :service_heartbeat,
      meeting_definition: weekly_definition,
      service_id: "ai_sns",
      due_cycle: :weekly,
      next_run_at: 10.days.from_now
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
      # Cadence 稼働状況セクション
      expect(response.body).to include("Cadence 稼働状況")
      # cadence カード（cadence 名は :weekly / :daily 等）
      expect(response.body).to include("weekly")
      expect(response.body).to include("daily")
      # サービス概要（ai_sns サービスのミーティングが存在するため表示される）
      expect(response.body).to include("ai_sns")
      # アラート表示（overdue チケットが存在するため待ちレビュー or 期限超過が出る）
      expect(response.body).to include("待ちレビュー")
      expect(response.body).to include("improvement")
    end

    it "KPI が存在する場合、ダッシュボードに KPI 状況セクションが表示される" do
      create(:kpi_ledger,
             kpi_key: "kpi:ai_sns_wau",
             scope_level: :service,
             service_id: "ai_sns",
             name: "WAU",
             status: :active,
             current_value: { "value" => 42 },
             thresholds: { "healthy" => 30, "warning" => 15 },
             grade: :healthy)

      get "/admin/ops/ledgers", headers: basic_auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("KPI 状況")
      expect(response.body).to include("healthy")
    end

    it "改善チケットが存在する場合、ダッシュボードに PDCA フローセクションが表示される" do
      get "/admin/ops/ledgers", headers: basic_auth_headers

      expect(response).to have_http_status(:ok)
      # improvement_ticket が let! で作られているので PDCA フローが描画される
      expect(response.body).to include("PDCA フロー")
      expect(response.body).to include("改善チケット 合計")
    end

    it "PlannerJob が JobWrapper 形式でも PDCA の最終実行時刻に反映される" do
      finished_at = Time.current.change(sec: 0) - 10.minutes
      SolidQueue::Job.create!(
        queue_name: "default",
        class_name: "ActiveJob::QueueAdapters::SolidQueueAdapter::JobWrapper",
        arguments: [ { "job_class" => "PlannerJob" } ].to_json,
        priority: 0,
        created_at: finished_at - 1.minute,
        updated_at: finished_at,
        finished_at: finished_at
      )

      get "/admin/ops/ledgers", headers: basic_auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Planner: #{finished_at.in_time_zone('Tokyo').strftime('%m/%d %H:%M')}")
    end

    it "schedule ページで heartbeat と open チケットが表示される" do
      get "/admin/ops/ledgers/schedule", headers: basic_auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("スケジュール")
      expect(response.body).to include("Ledger 圧縮期間設定")
      expect(response.body).to include("オープンチケット")
      expect(response.body).to include("overdue")
      expect(response.body).to include(weekly_ticket.id.to_s)
    end

    it "services ページで ai_sns サービスカードが表示される" do
      get "/admin/ops/ledgers/services", headers: basic_auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("ai_sns")
      expect(response.body).to include("picro")
    end

    it "service_detail で ai_sns サービス詳細が表示される" do
      get "/admin/ops/ledgers/services/ai_sns", headers: basic_auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("ai_sns")
    end

    it "show で MeetingLedger 詳細が表示される" do
      get "/admin/ops/ledgers/#{weekly_meeting.id}", headers: basic_auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("weekly_dept")
      expect(response.body).to include(weekly_meeting.id.to_s)
      expect(response.body).to include("hold_items")
      expect(response.body).to include(weekly_ticket.id.to_s)
    end

    it "show で hold_items の理由が LEDGER_HOLD_REASON_LABELS で日本語表示される（PR-2）" do
      # weekly_meeting は hold_items: [{ reason: "missing_kpi_definition", ... }] を持つ
      get "/admin/ops/ledgers/#{weekly_meeting.id}", headers: basic_auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("KPI定義なし（チケット保留）")
    end

    it "show で carry_over_items セクションが表示される（PR-1）" do
      weekly_meeting.update!(carry_over_items: [
        { "type" => "anomaly", "kpi_key" => "kpi:risk", "grade" => "critical" }
      ])

      get "/admin/ops/ledgers/#{weekly_meeting.id}", headers: basic_auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("carry_over_items")
      expect(response.body).to include("異常検知（KPI critical）")
    end

    it "show で directives improvements セクションが表示される（PR-6）" do
      meeting_with_improvements = create(
        :meeting_ledger,
        meeting_definition: weekly_definition,
        meeting_key: "weekly_dept",
        service_id: "ai_sns",
        directives: [ { improvements: { detected: 3, resolved: 1, details: [] } } ],
        status: :closed
      )

      get "/admin/ops/ledgers/#{meeting_with_improvements.id}", headers: basic_auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("improvements")
      expect(response.body).to include("検知")
      expect(response.body).to include("解消")
    end

    it "show で daily meeting に anomaly hold_items がある場合、daily → weekly 引き継ぎパネルを表示する（PR-3）" do
      daily_definition = MeetingDefinition.find_or_create_by!(meeting_key: "daily") do |d|
        d.meeting_type = :daily
        d.scope_level = :service
        d.service_id = "ai_sns"
        d.chair_role = "system"
        d.participant_roles = []
      end
      # weekly_meeting（let!）は held_at: Time.current。それより未来に設定することで
      # @next_weekly_meeting = nil になり「まだ次の weekly は実行されていません」が表示される
      daily_meeting = create(:meeting_ledger,
                             meeting_definition: daily_definition,
                             meeting_key: "daily",
                             meeting_type: :daily,
                             service_id: "ai_sns",
                             held_at: 1.minute.from_now,
                             hold_items: [ { "type" => "anomaly", "kpi_key" => "kpi:service_health", "grade" => "critical" } ],
                             status: :closed)

      get "/admin/ops/ledgers/#{daily_meeting.id}", headers: basic_auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("daily → weekly 引き継ぎ")
      expect(response.body).to include("まだ次の weekly は実行されていません")
    end

    it "show で daily meeting の後に weekly が実行済みの場合、次の weekly へのリンクを表示する（PR-3 @next_weekly_meeting）" do
      daily_definition = MeetingDefinition.find_or_create_by!(meeting_key: "daily") do |d|
        d.meeting_type = :daily
        d.scope_level = :service
        d.service_id = "ai_sns"
        d.chair_role = "system"
        d.participant_roles = []
      end
      daily_meeting = create(:meeting_ledger,
                             meeting_definition: daily_definition,
                             meeting_key: "daily",
                             meeting_type: :daily,
                             service_id: "ai_sns",
                             held_at: 3.hours.ago,
                             hold_items: [ { "type" => "anomaly", "kpi_key" => "kpi:service_health", "grade" => "critical" } ],
                             status: :closed)
      next_weekly = create(:meeting_ledger,
                           meeting_definition: weekly_definition,
                           meeting_key: "weekly_dept",
                           meeting_type: :weekly,
                           service_id: "ai_sns",
                           held_at: 1.hour.ago,
                           status: :closed)

      get "/admin/ops/ledgers/#{daily_meeting.id}", headers: basic_auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("daily → weekly 引き継ぎ")
      expect(response.body).to include("Meeting ##{next_weekly.id}")
    end

    it "ダッシュボードに Cadence フロー図が表示される（PR-4）" do
      get "/admin/ops/ledgers", headers: basic_auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Cadence フロー図")
      expect(response.body).to include("daily → weekly → monthly → quarterly → annual")
    end

    it "departments ページで日本語の役割名と状態が表示される" do
      get "/admin/ops/ledgers/departments", headers: basic_auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("企画部")
      expect(response.body).to include("有効")
    end

    it "department_detail ページで役割概要・主責務・主要タスクが表示される" do
      get "/admin/ops/ledgers/departments/#{planning_role.role_key}", headers: basic_auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("役割概要")
      expect(response.body).to include("主責務")
      expect(response.body).to include("主要タスク")
      expect(response.body).to include("市場・顧客分析")
    end
  end

  describe "POST /admin/ops/ledgers/time_axis" do
    it "認証ありで圧縮期間を更新できる" do
      ServiceTimeAxisSetting.create!(service_id: "ai_sns", cadence: :weekly, interval_seconds: 14_400)

      post "/admin/ops/ledgers/time_axis",
           params: { service_id: "ai_sns", cadence: "weekly", interval_seconds: 7200 },
           headers: basic_auth_headers

      expect(response).to redirect_to("/admin/ops/ledgers/schedule")

      setting = ServiceTimeAxisSetting.find_by!(service_id: "ai_sns", cadence: :weekly)
      expect(setting.interval_seconds).to eq(7200)
      expect(weekly_heartbeat.reload.next_run_at).to be_within(10.seconds).of(2.hours.from_now)
    end

    it "不正なサービスIDは更新せずリダイレクトする" do
      ServiceTimeAxisSetting.create!(service_id: "ai_sns", cadence: :weekly, interval_seconds: 14_400)

      post "/admin/ops/ledgers/time_axis",
           params: { service_id: "unknown", cadence: "weekly", interval_seconds: 7200 },
           headers: basic_auth_headers

      expect(response).to redirect_to("/admin/ops/ledgers/schedule")
      expect(ServiceTimeAxisSetting.find_by!(service_id: "ai_sns", cadence: :weekly).interval_seconds).to eq(14_400)
    end
  end

  def basic_auth_headers
    {
      "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials("ops", "secret")
    }
  end

  def extract_ticket_table_ids(html)
    document = Nokogiri::HTML(html)
    document.css("table[data-testid='ticket-ledger-table'] tbody tr td:first-child").map { |cell| cell.text.strip }
  end
end
