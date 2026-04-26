module Ledgers
  class ImprovementDetector
    OVERDUE_WINDOW_DAYS = 30
    STALE_SERVICE_DAYS = 14
    OVERDUE_RATE_THRESHOLD = 0.2
    IMPROVEMENT_DUE_DAYS = 14
    OPEN_STATUSES = %i[waiting_review overdue approved planned executing].freeze
    # Phase 42 / UI伴走管理: UI チェック会議が連続して未実施の場合に検知する閾値
    UI_CHECK_STALE_DAYS = 3
    UI_CHECK_SERVICE_ID = "ai_sns".freeze
    # ジョブ失敗継続検知: 過去 N 時間に M 回以上失敗したジョブクラスをチケット化
    JOB_FAILURE_WINDOW_HOURS = 6
    JOB_FAILURE_COUNT_THRESHOLD = 3

    def self.call
      new.call
    end

    def call
      created = []
      created.concat(detect_high_overdue_rate)
      created.concat(detect_missing_kpi_definition)
      created.concat(detect_stale_services)
      created.concat(detect_monthly_hold_accumulation)
      created.concat(detect_stale_ui_check)
      created.concat(detect_persistent_job_failures)

      notify_if_needed(created)

      {
        detected: created.count,
        details: created
      }
    end

    private

    def detect_high_overdue_rate
      tickets = TicketLedger.where(created_at: OVERDUE_WINDOW_DAYS.days.ago..Time.current)
      total_count = tickets.count
      return [] if total_count.zero?

      overdue_count = tickets.status_overdue.count
      rate = overdue_count.to_f / total_count
      return [] unless rate > OVERDUE_RATE_THRESHOLD

      rule = "high_overdue_rate"
      return [] if duplicate_rule_open?(rule:)

      linked_kpis = {
        rule:,
        overdue_count:,
        total_count:,
        rate: percent(rate)
      }
      ticket = create_ticket!(
        title: "Improvement: High overdue rate (#{percent(rate)})",
        linked_kpis:,
        scope_level: :company
      )

      [detail_payload(ticket:, linked_kpis:)]
    end

    def detect_missing_kpi_definition
      keys = recent_hold_items
        .select { |item| item[:reason] == "missing_kpi_definition" }
        .flat_map { |item| Array(item[:missing_kpi_keys]) }
        .compact
        .uniq
        .sort
      return [] if keys.blank?

      rule = "missing_kpi_definition"
      return [] if duplicate_rule_open?(rule:)

      linked_kpis = { rule:, keys: }
      ticket = create_ticket!(
        title: "Improvement: Missing KPI definitions (#{keys.size} keys)",
        linked_kpis:,
        scope_level: :company
      )

      [detail_payload(ticket:, linked_kpis:)]
    end

    def detect_stale_services
      ServiceLedger.pluck(:service_id).filter_map do |service_id|
        next if weekly_audit_exists_recently?(service_id:)
        next if duplicate_rule_open?(rule: "stale_service", service_id:)

        linked_kpis = {
          rule: "stale_service",
          service_id:,
          last_audit_at: last_audit_at(service_id:)&.iso8601
        }
        ticket = create_ticket!(
          title: "Improvement: Stale service - #{service_id} (no audit in 14+ days)",
          linked_kpis:,
          scope_level: :service,
          service_id:
        )

        detail_payload(ticket:, linked_kpis:)
      end
    end

    def detect_monthly_hold_accumulation
      meeting = MeetingLedger.where(meeting_key: "monthly_ops").order(held_at: :desc).first
      return [] unless meeting

      hold_count = Array(meeting.hold_items).count
      return [] if hold_count < 3

      rule = "monthly_hold_accumulation"
      return [] if duplicate_rule_open?(rule:)

      linked_kpis = { rule:, hold_count: }
      ticket = create_ticket!(
        title: "Improvement: Monthly ops has #{hold_count} held items",
        linked_kpis:,
        scope_level: :company
      )

      [detail_payload(ticket:, linked_kpis:)]
    end

    # Phase 42 / UI伴走管理: UI チェック会議（meeting_key: "ui_check"）が
    # UI_CHECK_STALE_DAYS 日以上実施されていない場合に検知する。
    def detect_stale_ui_check
      return [] if ui_check_recent?

      rule = "stale_ui_check"
      return [] if duplicate_rule_open?(rule:, service_id: UI_CHECK_SERVICE_ID)

      linked_kpis = {
        rule:,
        service_id: UI_CHECK_SERVICE_ID,
        last_check_at: last_ui_check_at&.iso8601
      }
      ticket = create_ticket!(
        title: "Improvement: UI check not run in #{UI_CHECK_STALE_DAYS}+ days (#{UI_CHECK_SERVICE_ID})",
        linked_kpis:,
        scope_level: :service,
        service_id: UI_CHECK_SERVICE_ID
      )

      [detail_payload(ticket:, linked_kpis:)]
    end

    # サービス・運営由来のジョブが繰り返し失敗している場合に検知する。
    # 過去 JOB_FAILURE_WINDOW_HOURS 時間以内に JOB_FAILURE_COUNT_THRESHOLD 回以上
    # 失敗した同一ジョブクラスごとに improvement チケットを起票する。
    def detect_persistent_job_failures
      window_start = JOB_FAILURE_WINDOW_HOURS.hours.ago
      scope = SolidQueue::FailedExecution.joins(:job).where(created_at: window_start..)
      scope = scope.where(discarded_at: nil) if SolidQueue::FailedExecution.column_names.include?("discarded_at")

      failure_counts = scope
        .group("solid_queue_jobs.class_name")
        .having("COUNT(*) >= ?", JOB_FAILURE_COUNT_THRESHOLD)
        .count

      return [] if failure_counts.blank?

      failure_counts.filter_map do |job_class_name, count|
        rule = "persistent_job_failure"
        next if open_improvement_tickets.any? { |t|
          linked = normalize_hash(t.linked_kpis)
          linked["rule"] == rule && linked["job_class"] == job_class_name
        }

        linked_kpis = {
          rule:,
          job_class: job_class_name,
          failure_count: count,
          window_hours: JOB_FAILURE_WINDOW_HOURS
        }
        ticket = create_ticket!(
          title: "Improvement: Persistent job failures - #{job_class_name} (#{count} in #{JOB_FAILURE_WINDOW_HOURS}h)",
          linked_kpis:,
          scope_level: :company
        )

        detail_payload(ticket:, linked_kpis:)
      end
    rescue => e
      Rails.logger.error("[ImprovementDetector] detect_persistent_job_failures error: #{e.message}")
      []
    end

    def create_ticket!(title:, linked_kpis:, scope_level:, service_id: nil)
      TicketLedger.create!(
        ticket_type: :improvement,
        title:,
        scope_level:,
        service_id:,
        source_meeting_type: :weekly,
        source_meeting: Ledgers::SystemMeetingProvider.for(kind: "improvement_detector"),
        linked_kpis:,
        linked_artifacts: [],
        priority: :medium,
        status: :approved,
        assignee: "improvement_detector",
        due_date: Date.current + IMPROVEMENT_DUE_DAYS.days,
        due_cycle: :weekly,
        # Phase 44e: 自動検知の improvement チケットは事後に CopilotInputTemplate で
        # template_id が付与されるため、作成時点では template guard を bypass する。
        skip_template_guard: true,
        # ImprovementDetector は検知した問題を解消するための自動起票エージェントであり、
        # kpi_breach StopLedger 由来の問題を検知してチケット化するケースがある。
        # stop guard をそのまま適用するとデッドロックになるため bypass する。
        skip_stop_guard: true
      )
    end

    def duplicate_rule_open?(rule:, service_id: nil)
      open_improvement_tickets.any? do |ticket|
        linked = normalize_hash(ticket.linked_kpis)
        next false unless linked["rule"] == rule
        next true if service_id.blank?

        linked["service_id"] == service_id
      end
    end

    def open_improvement_tickets
      @open_improvement_tickets ||= TicketLedger.ticket_type_improvement.where(status: OPEN_STATUSES)
    end

    def recent_hold_items
      @recent_hold_items ||= MeetingLedger
        .where(held_at: OVERDUE_WINDOW_DAYS.days.ago..Time.current)
        .where.not(hold_items: [])
        .flat_map { |meeting| Array(meeting.hold_items) }
        .map { |item| normalize_hash(item).symbolize_keys }
    end

    def weekly_audit_exists_recently?(service_id:)
      MeetingLedger.where(meeting_key: "weekly_dept", service_id:)
        .where(held_at: STALE_SERVICE_DAYS.days.ago..Time.current)
        .exists?
    end

    def last_audit_at(service_id:)
      MeetingLedger.where(meeting_key: "weekly_dept", service_id:).maximum(:held_at)
    end

    def ui_check_recent?
      MeetingLedger.where(meeting_key: "ui_check", service_id: UI_CHECK_SERVICE_ID)
                   .where(held_at: UI_CHECK_STALE_DAYS.days.ago..Time.current)
                   .exists?
    end

    def last_ui_check_at
      MeetingLedger.where(meeting_key: "ui_check", service_id: UI_CHECK_SERVICE_ID).maximum(:held_at)
    end

    def percent(rate)
      "#{(rate * 100).round(1)}%"
    end

    def detail_payload(ticket:, linked_kpis:)
      {
        ticket_id: ticket.id,
        rule: linked_kpis[:rule] || linked_kpis["rule"],
        title: ticket.title
      }
    end

    def notify_if_needed(created)
      return if created.blank?

      Ledgers::SlackNotifier.notify(
        operation: "detect_improvements",
        counts: { tickets_created: created.count, held_items: 0 },
        improvements: {
          detected: created.count,
          resolved: 0,
          details: created
        }
      )
    end

    def normalize_hash(value)
      case value
      when Hash
        value
      else
        {}
      end
    end
  end
end
