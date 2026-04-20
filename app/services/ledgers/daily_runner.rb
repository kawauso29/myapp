module Ledgers
  # 設計書 §12.6 選択肢A: daily cadence（圧縮 30分周期）の自動出力 Runner。
  #
  # 日次では「会議」を開かず、速報・異常検知・KPI スナップショットを
  # MeetingLedger（meeting_type: :daily）に記録する。
  # 出力は hold_items として蓄積し、次回の WeeklyDeptRunner に carry_over_items
  # として引き継がれる。
  class DailyRunner
    def self.call(service_id:)
      new(service_id:).call
    end

    def initialize(service_id:)
      @service_id = service_id
    end

    def call
      definition = meeting_definition!
      meeting = MeetingLedger.create!(
        meeting_definition: definition,
        meeting_key: definition.meeting_key,
        meeting_type: definition.meeting_type,
        scope_level: definition.scope_level,
        service_id: @service_id,
        chair: definition.chair_role,
        participants: [],
        role_fill_rate: nil,
        held_at: Time.current,
        status: :open,
        idempotency_key: Ledgers::IdempotencyKey.for_meeting(
          prefix: "daily",
          parts: [ @service_id ],
          cadence: :daily
        )
      )

      kpi_snapshot = collect_kpi_snapshot
      anomalies = detect_anomalies(kpi_snapshot)

      hold_items = []
      hold_items.concat(anomalies.map { |a| { type: "anomaly", **a } }) if anomalies.present?

      # 直前 daily meeting の hold_items を引き継ぐ（自分自身を除外）
      previous_daily = previous_daily_meeting(exclude_id: meeting.id)
      carry_over = previous_daily&.hold_items || []

      # Ledger自体の改善: 解消済み anomaly（KPIがcriticalでなくなった）をcarry_overから除去
      carry_over = filter_resolved_anomalies(carry_over, kpi_snapshot)

      meeting.update!(
        decisions: [ { kpi_snapshot:, anomaly_count: anomalies.size } ],
        hold_items: carry_over + hold_items,
        carry_over_items: carry_over + hold_items,
        directives: [ { daily_summary: true, kpi_count: kpi_snapshot.size } ],
        status: :closed
      )

      # 成果物台帳に日次サマリーを記録
      Ledgers::RunnerArtifactPublisher.publish_for!(
        meeting: meeting,
        runner: :daily,
        service_id: @service_id
      )

      meeting
    end

    private

    def meeting_definition!
      MeetingDefinition.find_by!(meeting_key: "daily", scope_level: :service)
    end

    def collect_kpi_snapshot
      KpiLedger.where(service_id: @service_id, status: :active).map do |kpi|
        {
          kpi_key: kpi.kpi_key,
          current_value: kpi.current_value,
          grade: kpi.grade
        }.compact
      end
    end

    def detect_anomalies(kpi_snapshot)
      kpi_snapshot.select { |kpi| kpi[:grade] == "critical" }.map do |kpi|
        { kpi_key: kpi[:kpi_key], grade: kpi[:grade], current_value: kpi[:current_value] }
      end
    end

    def previous_daily_meeting(exclude_id: nil)
      scope = MeetingLedger.where(
        meeting_type: :daily,
        service_id: @service_id
      )
      scope = scope.where.not(id: exclude_id) if exclude_id
      scope.order(held_at: :desc).first
    end

    # 解消済み anomaly を carry_over から除去する。
    # JSONB から読み込んだ hold_items は string key、新規作成分は symbol key なので両方対応する。
    # anomaly 以外の hold_item（escalation 等）はそのまま残す。
    def filter_resolved_anomalies(carry_over, kpi_snapshot)
      current_critical_keys = kpi_snapshot
        .select { |kpi| kpi[:grade] == "critical" }
        .map { |kpi| kpi[:kpi_key] }
        .to_set

      carry_over.reject do |item|
        item_type = item["type"] || item[:type]
        item_kpi  = item["kpi_key"] || item[:kpi_key]
        item_type == "anomaly" && item_kpi.present? && !current_critical_keys.include?(item_kpi)
      end
    end
  end
end
