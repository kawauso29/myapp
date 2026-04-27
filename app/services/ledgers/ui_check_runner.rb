module Ledgers
  # Phase 42 / UI伴走管理: AI SNS の UI チェック会議（meeting_key: "ui_check"）を実行する。
  #
  # 2日ごとに自動実行され、UI固有KPI（画面稼働率・クラッシュ率・WAU）を確認する。
  # このMeetingLedger作成が ImprovementDetector#ui_check_recent? の判定基準となる。
  # stale_ui_check ルールによる改善チケット起票を防ぐには、3日以内に1回以上実行される必要がある。
  class UiCheckRunner
    SERVICE_ID = "ai_sns".freeze
    UI_KPI_KEYS = %w[kpi:ai_sns_ui_screen_coverage kpi:ai_sns_ui_crash_rate kpi:ai_sns_wau].freeze

    def self.call
      new.call
    end

    def call
      definition = meeting_definition!
      preflight = Ledgers::PreflightValidator.call(definition:, present_roles: nil)
      meeting = MeetingLedger.create!(
        meeting_definition: definition,
        meeting_key: definition.meeting_key,
        meeting_type: definition.meeting_type,
        scope_level: definition.scope_level,
        service_id: SERVICE_ID,
        chair: definition.chair_role,
        participants: preflight.participants,
        role_fill_rate: preflight.role_fill_rate,
        held_at: Time.current,
        status: :open,
        idempotency_key: Ledgers::IdempotencyKey.for_meeting(
          prefix: "ui_check",
          parts: [ SERVICE_ID ],
          cadence: :quarterly
        )
      )

      kpi_snapshot = collect_ui_kpi_snapshot
      anomalies = detect_ui_anomalies(kpi_snapshot)
      hold_items = anomalies.map { |a| { type: "anomaly", **a } }

      meeting.update!(
        decisions: [ { kpi_snapshot:, anomaly_count: anomalies.size } ],
        hold_items:,
        carry_over_items: hold_items,
        directives: [ { ui_check: true, kpi_count: kpi_snapshot.size } ],
        minutes: Ledgers::MinutesGenerator.for_ui_check(
          service_id: SERVICE_ID,
          kpi_snapshot:,
          anomalies:
        ),
        status: :closed
      )

      meeting
    end

    private

    def meeting_definition!
      MeetingDefinition.find_by!(meeting_key: "ui_check", scope_level: :service)
    end

    def collect_ui_kpi_snapshot
      KpiLedger.where(service_id: SERVICE_ID, kpi_key: UI_KPI_KEYS, status: :active).map do |kpi|
        {
          kpi_key: kpi.kpi_key,
          current_value: kpi.current_value,
          grade: kpi.grade
        }.compact
      end
    end

    def detect_ui_anomalies(kpi_snapshot)
      kpi_snapshot.select { |kpi| kpi[:grade] == "critical" }.map do |kpi|
        { kpi_key: kpi[:kpi_key], grade: kpi[:grade], current_value: kpi[:current_value] }
      end
    end
  end
end
