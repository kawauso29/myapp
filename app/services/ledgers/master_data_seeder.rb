module Ledgers
  # ledger 運営に必須なマスタデータを冪等に投入するサービス。
  #
  # `db:seed` と `ledgers:seed_master_data` rake タスクの両方から呼ばれる。
  # 全操作が `find_or_create_by!` ベースで冪等なため、デプロイ毎に安全に実行できる。
  #
  # 対象:
  #   - MeetingDefinition / ServiceHeartbeat
  #   - ServiceLedger / KpiLedger
  #   - LaneCapacityCap
  #   - KnowledgeLedger (ADR)
  class MasterDataSeeder
    def self.call
      new.call
    end

    def call
      seed_meeting_definitions!
      seed_service_and_kpi_ledgers!
      seed_lane_capacity_caps!
      seed_ui_knowledge_adr!
    end

    private

    def seed_meeting_definitions!
      weekly = MeetingDefinition.find_or_create_by!(meeting_key: "weekly_dept") do |d|
        d.meeting_type = :weekly
        d.scope_level = :service
        d.service_id = "ai_sns"
        d.chair_role = "business_owner"
        d.participant_roles = %w[planning dev audit cs business_owner]
        d.writes_ledgers = %w[meeting_ledger ticket_ledger]
      end

      monthly = MeetingDefinition.find_or_create_by!(meeting_key: "monthly_ops") do |d|
        d.meeting_type = :monthly
        d.scope_level = :company
        d.chair_role = "business_owner"
        d.participant_roles = %w[executive_planning executive_development executive_audit executive_hr business_owner]
        d.writes_ledgers = %w[meeting_ledger ticket_ledger]
      end

      MeetingDefinition.find_or_create_by!(meeting_key: "quarterly_review") do |d|
        d.meeting_type = :quarterly_review
        d.scope_level = :company
        d.chair_role = "cto"
        d.participant_roles = %w[executive_planning executive_development executive_audit executive_hr business_owner]
        d.writes_ledgers = %w[meeting_ledger ticket_ledger]
      end

      MeetingDefinition.find_or_create_by!(meeting_key: "annual_plan") do |d|
        d.meeting_type = :annual_plan
        d.scope_level = :company
        d.chair_role = "ceo"
        d.participant_roles = %w[executive_planning executive_development executive_audit executive_hr business_owner]
        d.writes_ledgers = %w[meeting_ledger ticket_ledger]
      end

      ServiceHeartbeat.find_or_create_by!(meeting_definition: weekly, service_id: "ai_sns") do |h|
        h.due_cycle = :weekly
        h.status = :active
        h.next_run_at = 1.week.from_now
      end

      ServiceHeartbeat.find_or_create_by!(meeting_definition: monthly, service_id: nil) do |h|
        h.due_cycle = :monthly
        h.status = :active
        h.next_run_at = 1.month.from_now
      end

      # Phase 42 / UI伴走管理: AI SNS UI サービス向け2日周期チェック定義（ai_sns に統合済み）
      ui_check = MeetingDefinition.find_or_create_by!(meeting_key: "ui_check") do |d|
        d.meeting_type = :weekly
        d.scope_level = :service
        d.service_id = "ai_sns"
        d.chair_role = "business_owner"
        d.participant_roles = %w[planning dev audit business_owner]
        d.writes_ledgers = %w[meeting_ledger ticket_ledger]
      end

      ServiceHeartbeat.find_or_create_by!(meeting_definition: ui_check, service_id: "ai_sns") do |h|
        h.due_cycle = :weekly
        h.status = :active
        h.next_run_at = 2.days.from_now
      end
    end

    def seed_service_and_kpi_ledgers!
      ServiceLedger.find_or_create_by!(service_id: "ai_sns") do |s|
        s.scope_level = :service
        s.business_owner = "unassigned_business_owner"
        s.status = :active
      end

      [
        { kpi_key: "kpi:service_health", name: "Service Health", scope_level: :service, service_id: "ai_sns",
          thresholds: { "healthy" => 0.8, "warning" => 0.4, "direction" => "higher_better" },
          target_value: { "value" => 0.8, "unit" => "score_0_1", "source" => "seed" } },
        { kpi_key: "kpi:ai_sns_wau", name: "AI SNS WAU", scope_level: :service, service_id: "ai_sns",
          thresholds: { "healthy" => 1000, "warning" => 300, "direction" => "higher_better" },
          target_value: { "value" => 1000, "unit" => "users", "source" => "seed" } },
        { kpi_key: "kpi:ai_sns_retention_7d", name: "AI SNS Retention 7d", scope_level: :service, service_id: "ai_sns",
          thresholds: { "healthy" => 40, "warning" => 20, "direction" => "higher_better" },
          target_value: { "value" => 40, "unit" => "percent", "source" => "seed" } },
        { kpi_key: "kpi:ai_sns_paid_conversion", name: "AI SNS Paid Conversion", scope_level: :service, service_id: "ai_sns",
          thresholds: { "healthy" => 5, "warning" => 1, "direction" => "higher_better" },
          target_value: { "value" => 5, "unit" => "percent", "source" => "seed" } },
        { kpi_key: "kpi:company_revenue_growth", name: "Company Revenue Growth", scope_level: :company, service_id: nil,
          thresholds: { "healthy" => 10, "warning" => 0, "direction" => "higher_better" },
          target_value: { "value" => 10, "unit" => "percent", "source" => "seed" } },
        # Phase 2 補強 / 穴③: 顧客フィードバック満足度 KPI（CustomerFeedbackLedger 由来）
        { kpi_key: "kpi:customer_feedback", name: "Customer Feedback Satisfaction", scope_level: :service, service_id: "ai_sns",
          thresholds: { "healthy" => 90, "warning" => 70, "direction" => "higher_better" },
          target_value: { "value" => 90, "unit" => "percent", "source" => "seed" } }
      ].each do |attrs|
        KpiLedger.find_or_create_by!(kpi_key: attrs[:kpi_key]) do |k|
          k.scope_level = attrs[:scope_level]
          k.service_id = attrs[:service_id]
          k.name = attrs[:name]
          k.status = :active
          k.thresholds = attrs[:thresholds] || {}
          k.target_value = attrs[:target_value] || {}
        end
      end
    end

    def seed_lane_capacity_caps!
      # Phase 2 補強 / 穴⑤: LaneCapacityCap が seed 投入されていないと WIP 上限が機能しない
      [
        { operating_lane: :immediate, wip_cap: 5 },
        { operating_lane: :weekly_improvement, wip_cap: 4 },
        { operating_lane: :monthly_ops, wip_cap: 3 },
        { operating_lane: :quarterly_review, wip_cap: 2 }
      ].each do |attrs|
        LaneCapacityCap.find_or_create_by!(
          scope_level: :service,
          service_id: "ai_sns",
          operating_lane: attrs[:operating_lane]
        ) do |cap|
          cap.wip_cap = attrs[:wip_cap]
        end
      end

      # Phase 42: UI 固有 KPI（画面稼働率 / クラッシュ率）は ai_sns サービスに統合済み
      [
        { kpi_key: "kpi:ai_sns_ui_screen_coverage", name: "AI SNS UI Screen Coverage", scope_level: :service, service_id: "ai_sns",
          thresholds: { "healthy" => 90.0, "warning" => 60.0, "direction" => "higher_better" } },
        { kpi_key: "kpi:ai_sns_ui_crash_rate", name: "AI SNS UI Crash Rate", scope_level: :service, service_id: "ai_sns",
          thresholds: { "healthy" => 0.5, "warning" => 2.0, "direction" => "lower_better" } }
      ].each do |attrs|
        KpiLedger.find_or_create_by!(kpi_key: attrs[:kpi_key]) do |k|
          k.scope_level = attrs[:scope_level]
          k.service_id = attrs[:service_id]
          k.name = attrs[:name]
          k.status = :active
          k.thresholds = attrs[:thresholds]
        end
      end
    end

    def seed_ui_knowledge_adr!
      # Phase 42: AI SNS UI 仕様を KnowledgeLedger（ADR）として記録する初期データ
      KnowledgeLedger.find_or_create_by!(idempotency_key: "adr:ai_sns_ui:v1") do |ledger|
        ledger.kind = :adr
        ledger.title = "ADR-UI-001: AI SNS UI Screen Requirements and Acceptance Criteria"
        ledger.body = <<~BODY
          ## Context
          AI SNS の Expo (React Native Web) UI は Phase 1〜3 で実装済み。
          本 ADR は実装済み画面の一覧と受け入れ基準を台帳に記録し、
          UiCheckLedgerRunJob（2日周期）のチェックサイクルで継続的に管理する。

          ## Decision
          実装済み画面（7画面）を正本として扱う：
          1. ログイン画面 (auth/sign-in)
          2. タイムライン画面 (tabs/index)
          3. AI詳細画面 (ai/[id])
          4. 投稿詳細画面 (post/[id])
          5. 検索画面 (tabs/search)
          6. 発見画面 (tabs/discover)
          7. マイページ画面 (tabs/profile)

          ## Acceptance Criteria
          - WAU > 0（週1人以上がUIを利用）
          - 全7画面がナビゲーション到達可能
          - クラッシュ率 < 0.5%（フロントエンド計装後に計測予定。Sentry等の導入が前提。
            現時点では kpi:ai_sns_ui_crash_rate は nil を返し KpiAutoCollector でスキップされる。
            TODO: Sentry/Expo crash reporting 導入後に KpiAutoCollector の compute を実装する）

          ## Status
          accepted
        BODY
        ledger.status = :accepted
        ledger.accepted_at = Time.current
        ledger.tags = { "service_id" => "ai_sns", "version" => "v1", "screens" => 7 }
      end
    end
  end
end
