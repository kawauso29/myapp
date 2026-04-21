# frozen_string_literal: true

require "rails_helper"

# ============================================================
# Ledger Cadence フロー統合テスト
#
# 圧縮時間軸 (§11) の 5 cadence が次のように情報を引き継ぐことを検証する。
#
#   daily (30分) ─→ weekly (4h) ─→ monthly (12h) ─→ quarterly (2日) ─→ annual (7日)
#
# 各 Runner の責務:
#   daily    : KPI スナップショット取得 + critical KPI を anomaly として hold_items に記録
#   weekly   : daily.hold_items (anomaly) を ticket_inputs に変換しチケット起票
#              処理できない入力（KPI 欠落など）を hold_items / carry_over_items に保持
#   monthly  : 前回 weekly の hold_items を carry_over_items として引き継ぐ
#              waiting_review チケットを月次決議（approved / cancelled など）で解決
#   quarterly: 前回 monthly の hold_items を carry_over_items として引き継ぐ
#              期間集計サマリーチケットを起票
#   annual   : 前回 quarterly の hold_items を carry_over_items として引き継ぐ
#              全 cadence 集計 + FY 計画チケットを起票
# ============================================================
RSpec.describe "Ledger Cadence Flow: daily → weekly → monthly → quarterly → annual" do
  # ------------------------------------
  # MeetingDefinition セットアップ
  # ------------------------------------
  let!(:daily_definition) do
    MeetingDefinition.find_or_create_by!(meeting_key: "daily") do |d|
      d.meeting_type = :daily
      d.scope_level = :service
      d.service_id = "ai_sns"
      d.chair_role = "system"
      d.participant_roles = []
    end
  end

  let!(:weekly_definition) do
    MeetingDefinition.find_or_create_by!(meeting_key: "weekly_dept") do |d|
      d.meeting_type = :weekly
      d.scope_level = :service
      d.service_id = "ai_sns"
      d.chair_role = "business_owner"
      d.participant_roles = %w[planning dev audit cs business_owner]
    end
  end

  let!(:monthly_definition) do
    MeetingDefinition.find_or_create_by!(meeting_key: "monthly_ops") do |d|
      d.meeting_type = :monthly
      d.scope_level = :company
      d.service_id = nil
      d.chair_role = "business_owner"
      d.participant_roles = %w[executive_planning executive_development executive_audit executive_hr business_owner]
    end
  end

  let!(:quarterly_definition) do
    MeetingDefinition.find_or_create_by!(meeting_key: "quarterly_review") do |d|
      d.meeting_type = :quarterly_review
      d.scope_level = :company
      d.service_id = nil
      d.chair_role = "cto"
      d.participant_roles = %w[executive_planning executive_development executive_audit executive_hr business_owner]
    end
  end

  let!(:annual_definition) do
    MeetingDefinition.find_or_create_by!(meeting_key: "annual_plan") do |d|
      d.meeting_type = :annual_plan
      d.scope_level = :company
      d.service_id = nil
      d.chair_role = "ceo"
      d.participant_roles = %w[executive_planning executive_development executive_audit executive_hr business_owner]
    end
  end

  # ------------------------------------
  # KPI 台帳セットアップ（テスト専用キーを使い既存seedデータとの衝突を回避）
  # ------------------------------------
  let!(:healthy_kpi) do
    create(:kpi_ledger,
           kpi_key: "kpi:flow_test_healthy",
           scope_level: :service,
           service_id: "ai_sns",
           status: :active,
           current_value: { "value" => 0.9 },
           grade: "healthy")
  end

  let!(:critical_kpi) do
    create(:kpi_ledger,
           kpi_key: "kpi:flow_test_critical",
           scope_level: :service,
           service_id: "ai_sns",
           status: :active,
           current_value: { "value" => 0.0 },
           grade: "critical")
  end

  # ------------------------------------
  # 改善検知・解消・エスカレーション系はフロー検証の対象外のためスタブ化
  # ------------------------------------
  before do
    allow(Ledgers::ImprovementDetector).to receive(:call).and_return({ detected: 0, details: [] })
    allow(Ledgers::ImprovementResolver).to receive(:call).and_return({ resolved: 0, details: [] })
    allow(Ledgers::ImprovementEscalator).to receive(:call).and_return(
      operation: "escalate_improvements",
      overdue_marked: 0,
      escalated_monthly: 0,
      escalated_quarterly: 0,
      details: []
    )
  end

  # ============================================================
  # Stage 1: DailyRunner
  # ============================================================
  describe "Stage 1: DailyRunner - KPI異常検知とhold_items記録" do
    it "critical KPI を anomaly として hold_items / carry_over_items に記録する" do
      meeting = Ledgers::DailyRunner.call(service_id: "ai_sns")

      expect(meeting).to be_meeting_type_daily
      expect(meeting).to be_status_closed
      expect(meeting.chair).to eq("system")
      expect(meeting.participants).to eq([])

      # KPI スナップショットが decisions に記録される
      expect(meeting.decisions.first).to include("kpi_snapshot", "anomaly_count" => 1)

      # critical KPI が anomaly として hold_items に積まれる
      expect(meeting.hold_items).to include(
        a_hash_including("type" => "anomaly", "kpi_key" => "kpi:flow_test_critical", "grade" => "critical")
      )
      # carry_over_items = hold_items（次サイクルに引き継ぐ）
      expect(meeting.carry_over_items).to eq(meeting.hold_items)

      # healthy KPI は anomaly に含まれない
      anomaly_keys = meeting.hold_items.map { |i| i["kpi_key"] }
      expect(anomaly_keys).not_to include("kpi:flow_test_healthy")
    end

    it "前回 daily の hold_items は critical が継続中なら carry_over に残る" do
      first = Ledgers::DailyRunner.call(service_id: "ai_sns")
      first.update!(hold_items: [{ "type" => "anomaly", "kpi_key" => "kpi:flow_test_critical" }],
                    idempotency_key: "daily:ai_sns:old_slot")

      second = Ledgers::DailyRunner.call(service_id: "ai_sns")

      expect(second.carry_over_items).to include(
        a_hash_including("type" => "anomaly", "kpi_key" => "kpi:flow_test_critical")
      )
    end

    it "KPI が critical でなくなったら carry_over から除去される（解消検知）" do
      first = Ledgers::DailyRunner.call(service_id: "ai_sns")
      # 前回 hold に kpi:flow_test_healthy の anomaly が残っていると仮定
      first.update!(hold_items: [{ "type" => "anomaly", "kpi_key" => "kpi:flow_test_healthy" }],
                    idempotency_key: "daily:ai_sns:old_slot")

      # service_health は healthy なので 2 回目の daily では除去される
      second = Ledgers::DailyRunner.call(service_id: "ai_sns")

      anomaly_keys = second.carry_over_items
                           .select { |i| i["type"] == "anomaly" }
                           .map { |i| i["kpi_key"] }
      expect(anomaly_keys).not_to include("kpi:flow_test_healthy")
    end
  end

  # ============================================================
  # Stage 2: WeeklyDeptRunner
  # ============================================================
  describe "Stage 2: WeeklyDeptRunner - daily異常のticket化とhold_items生成" do
    let!(:daily_meeting) do
      create(:meeting_ledger,
             meeting_definition: daily_definition,
             meeting_key: "daily",
             meeting_type: :daily,
             service_id: "ai_sns",
             held_at: 1.hour.ago,
             hold_items: [
               { "type" => "anomaly", "kpi_key" => "kpi:flow_test_critical", "grade" => "critical" }
             ])
    end

    it "daily anomaly を waiting_review チケットに変換して escalation_to: monthly を付与する" do
      weekly = Ledgers::WeeklyDeptRunner.call(
        service_id: "ai_sns",
        ticket_inputs: []
      )

      anomaly_ticket = TicketLedger.find_by(title: "Anomaly: kpi:flow_test_critical")
      expect(anomaly_ticket).to be_present
      expect(anomaly_ticket).to be_status_waiting_review
      expect(anomaly_ticket.escalation_to).to eq("monthly")
      expect(anomaly_ticket.linked_kpis).to include("kpi:flow_test_critical")

      # チケット化されたので tickets_to_create に記録される
      expect(weekly.tickets_to_create).to include(a_hash_including("ticket_id" => anomaly_ticket.id))
    end

    it "KPI 欠落の ticket_input は hold_items に保持されて carry_over_items にコピーされる" do
      weekly = Ledgers::WeeklyDeptRunner.call(
        service_id: "ai_sns",
        use_daily_anomalies: false,
        ticket_inputs: [
          { ticket_type: "ops", title: "missing kpi item", linked_kpis: [] }
        ]
      )

      expect(weekly.hold_items).to include(
        a_hash_including("title" => "missing kpi item", "reason" => "missing_linked_kpis")
      )
      # hold_items と carry_over_items は一致
      expect(weekly.carry_over_items).to eq(weekly.hold_items)
    end
  end

  # ============================================================
  # Stage 3: MonthlyOpsRunner
  # ============================================================
  describe "Stage 3: MonthlyOpsRunner - weekly hold_itemsのcarry_over引き継ぎ" do
    let!(:prev_weekly) do
      create(:meeting_ledger,
             meeting_definition: weekly_definition,
             meeting_key: "weekly_dept",
             meeting_type: :weekly,
             held_at: 1.hour.ago,
             hold_items: [{ "title" => "weekly unresolved", "reason" => "missing_kpi_definition" }])
    end

    it "前回 weekly の hold_items を carry_over_items として引き継ぐ" do
      monthly = Ledgers::MonthlyOpsRunner.call(resolution_map: {})

      expect(monthly.carry_over_items).to eq([{ "title" => "weekly unresolved", "reason" => "missing_kpi_definition" }])
    end

    it "waiting_review チケットを月次決議で解決する" do
      waiting = create(:ticket_ledger,
                       status: :waiting_review,
                       escalation_to: :monthly,
                       due_cycle: :monthly)

      monthly = Ledgers::MonthlyOpsRunner.call(resolution_map: { waiting.id => "approved" })

      expect(waiting.reload).to be_status_approved
      expect(waiting.reload.escalation_to).to be_nil
      expect(monthly.decisions).to include(a_hash_including("ticket_id" => waiting.id, "resolution" => "approved"))
    end
  end

  # ============================================================
  # Stage 4: QuarterlyReviewRunner
  # ============================================================
  describe "Stage 4: QuarterlyReviewRunner - monthly hold_itemsのcarry_over引き継ぎ" do
    let!(:prev_monthly) do
      create(:meeting_ledger,
             meeting_definition: monthly_definition,
             meeting_key: "monthly_ops",
             meeting_type: :monthly,
             held_at: 1.day.ago,
             hold_items: [{ "title" => "monthly unresolved" }])
    end

    it "前回 monthly の hold_items を carry_over_items として引き継ぐ" do
      quarterly = Ledgers::QuarterlyReviewRunner.call

      expect(quarterly.carry_over_items).to eq([{ "title" => "monthly unresolved" }])
    end

    it "期間集計サマリーチケットを起票する" do
      quarterly = Ledgers::QuarterlyReviewRunner.call

      ticket = TicketLedger.where(ticket_type: "quarterly_review").last
      expect(ticket).to be_present
      expect(ticket).to be_status_approved
      expect(ticket.title).to match(/^Q\d #{Date.current.year} Review Summary$/)
      expect(ticket.due_date).to eq(Ledgers::TimeAxis.due_date_for(:quarterly))
    end
  end

  # ============================================================
  # Stage 5: AnnualPlanRunner
  # ============================================================
  describe "Stage 5: AnnualPlanRunner - quarterly hold_itemsのcarry_over引き継ぎ" do
    before do
      MeetingLedger.delete_all
      TicketLedger.delete_all
    end

    let!(:prev_quarterly) do
      create(:meeting_ledger,
             meeting_definition: quarterly_definition,
             meeting_key: "quarterly_review",
             meeting_type: :quarterly_review,
             held_at: 3.days.ago,
             hold_items: [{ "title" => "quarterly unresolved" }])
    end

    it "前回 quarterly の hold_items を carry_over_items として引き継ぐ" do
      annual = Ledgers::AnnualPlanRunner.call

      expect(annual.carry_over_items).to eq([{ "title" => "quarterly unresolved" }])
    end

    it "全 cadence 集計 FY 計画チケットを起票する" do
      annual = Ledgers::AnnualPlanRunner.call

      ticket = TicketLedger.where(ticket_type: "annual_plan").last
      expect(ticket).to be_present
      expect(ticket.title).to eq("FY#{Date.current.year} Annual Plan")
      expect(ticket).to be_status_approved
      expect(ticket.due_date).to eq(Ledgers::TimeAxis.due_date_for(:annual))
    end
  end

  # ============================================================
  # フルチェーン統合: daily → weekly → monthly の連鎖を一気通貫で検証
  # ============================================================
  describe "フルチェーン: daily anomaly が weekly ticket → monthly carry_over へと連鎖する" do
    it "critical KPI が検知されてから monthly carry_over_items に引き継がれるまでの全フローを検証する" do
      # --------------------------------------------------
      # Step 1: Daily - critical KPI を anomaly として記録
      # --------------------------------------------------
      daily = Ledgers::DailyRunner.call(service_id: "ai_sns")

      expect(daily).to be_meeting_type_daily
      expect(daily.hold_items).to include(a_hash_including("type" => "anomaly", "kpi_key" => "kpi:flow_test_critical"))

      # --------------------------------------------------
      # Step 2: Weekly - daily anomaly → ticket + 別入力 → hold_item
      # --------------------------------------------------
      weekly = Ledgers::WeeklyDeptRunner.call(
        service_id: "ai_sns",
        ticket_inputs: [
          # anomaly 由来のチケットに加え、KPI 欠落の入力で hold_item も生成する
          { ticket_type: "ops", title: "hold me: no kpi", linked_kpis: [] }
        ]
      )

      # daily anomaly → waiting_review チケット
      anomaly_ticket = TicketLedger.find_by(title: "Anomaly: kpi:flow_test_critical")
      expect(anomaly_ticket).to be_status_waiting_review
      expect(anomaly_ticket.escalation_to).to eq("monthly")

      # KPI 欠落入力 → hold_item
      expect(weekly.hold_items).to include(
        a_hash_including("title" => "hold me: no kpi", "reason" => "missing_linked_kpis")
      )
      expect(weekly.carry_over_items).to eq(weekly.hold_items)

      # --------------------------------------------------
      # Step 3: Monthly - weekly hold_items を carry_over
      # --------------------------------------------------
      monthly = Ledgers::MonthlyOpsRunner.call(
        resolution_map: { anomaly_ticket.id => "approved" }
      )

      # waiting_review チケットが月次で解決される
      expect(anomaly_ticket.reload).to be_status_approved

      # weekly の hold_items が monthly の carry_over_items に引き継がれる
      expect(monthly.carry_over_items).to eq(weekly.hold_items)
      expect(monthly.carry_over_items).to include(
        a_hash_including("title" => "hold me: no kpi")
      )
    end
  end
end
