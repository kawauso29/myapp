module Ledgers
  # Phase 45 / §20 / §16: 各部署のドキュメント健全性と会議継続性を自動検知する。
  #
  # ImprovementDetector と同じ TicketLedger 自動起票パターンを使い、
  # 下記 5 つのルールを評価して問題があれば improvement チケットを起票する。
  #
  # ルール一覧:
  #   no_runbook_update   - Runbook が RUNBOOK_STALE_DAYS 日以上作成なし（dev 担当）
  #   no_customer_notice  - customer_notice が CUSTOMER_NOTICE_STALE_DAYS 日以上作成なし（cs 担当）
  #   stale_artifact      - published ArtifactLedger が STALE_ARTIFACT_DAYS 日以上更新なし（planning 担当）
  #   missing_adr         - ADR が RUNBOOK_STALE_DAYS 日以上作成なし（dev / audit 担当）
  #   dept_meeting_skip   - サービスの weekly_dept 会議が MEETING_SKIP_DAYS 日以上未実施（全部署）
  #
  # DailyRunner から毎 30 分周期で呼び出される。
  # duplicate_rule_open? で重複チケット起票を抑止しているため高頻度呼び出しでも安全。
  class DeptHealthChecker
    RUNBOOK_STALE_DAYS          = 30
    CUSTOMER_NOTICE_STALE_DAYS  = 30
    STALE_ARTIFACT_DAYS         = 90
    MEETING_SKIP_DAYS           = 14
    IMPROVEMENT_DUE_DAYS        = 14
    OPEN_STATUSES               = %i[waiting_review overdue approved planned executing].freeze

    # ルールキー一覧（コントローラ・ビューからの参照用）
    RULES = %w[
      no_runbook_update
      no_customer_notice
      stale_artifact
      missing_adr
      dept_meeting_skip
    ].freeze

    def self.call
      new.call
    end

    def call
      created = []
      created.concat(detect_no_runbook_update)
      created.concat(detect_no_customer_notice)
      created.concat(detect_stale_artifacts)
      created.concat(detect_missing_adr)
      created.concat(detect_dept_meeting_skip)

      notify_if_needed(created)

      { detected: created.count, details: created }
    end

    private

    # ルール1: Runbook が RUNBOOK_STALE_DAYS 日以上作成されていない
    def detect_no_runbook_update
      return [] if KnowledgeLedger.kind_runbook
                                  .where(created_at: RUNBOOK_STALE_DAYS.days.ago..)
                                  .exists?

      rule = "no_runbook_update"
      return [] if duplicate_rule_open?(rule:)

      last_runbook = KnowledgeLedger.kind_runbook.order(created_at: :desc).first
      linked_kpis = {
        rule:,
        last_created_at: last_runbook&.created_at&.iso8601,
        stale_days: RUNBOOK_STALE_DAYS
      }
      ticket = create_ticket!(
        title: "Dept Health: No runbook created in #{RUNBOOK_STALE_DAYS}+ days",
        linked_kpis:,
        scope_level: :company
      )
      [detail_payload(ticket:, linked_kpis:)]
    end

    # ルール2: customer_notice が CUSTOMER_NOTICE_STALE_DAYS 日以上作成されていない
    def detect_no_customer_notice
      return [] if ArtifactLedger.artifact_type_customer_notice
                                  .where(created_at: CUSTOMER_NOTICE_STALE_DAYS.days.ago..)
                                  .exists?

      rule = "no_customer_notice"
      return [] if duplicate_rule_open?(rule:)

      last_notice = ArtifactLedger.artifact_type_customer_notice.order(created_at: :desc).first
      linked_kpis = {
        rule:,
        last_created_at: last_notice&.created_at&.iso8601,
        stale_days: CUSTOMER_NOTICE_STALE_DAYS
      }
      ticket = create_ticket!(
        title: "Dept Health: No customer notice in #{CUSTOMER_NOTICE_STALE_DAYS}+ days",
        linked_kpis:,
        scope_level: :company
      )
      [detail_payload(ticket:, linked_kpis:)]
    end

    # ルール3: published ArtifactLedger が STALE_ARTIFACT_DAYS 日以上更新なし
    def detect_stale_artifacts
      stale_scope = ArtifactLedger.status_published
                                  .where(updated_at: ..STALE_ARTIFACT_DAYS.days.ago)
      return [] if stale_scope.none?

      rule = "stale_artifact"
      return [] if duplicate_rule_open?(rule:)

      oldest  = stale_scope.order(updated_at: :asc).first
      linked_kpis = {
        rule:,
        stale_count: stale_scope.count,
        oldest_title: oldest.title,
        oldest_updated_at: oldest.updated_at.iso8601
      }
      ticket = create_ticket!(
        title: "Dept Health: #{stale_scope.count} stale published artifacts (#{STALE_ARTIFACT_DAYS}+ days old)",
        linked_kpis:,
        scope_level: :company
      )
      [detail_payload(ticket:, linked_kpis:)]
    end

    # ルール4: ADR が RUNBOOK_STALE_DAYS 日以上作成されていない
    def detect_missing_adr
      return [] if KnowledgeLedger.kind_adr
                                  .where(created_at: RUNBOOK_STALE_DAYS.days.ago..)
                                  .exists?

      rule = "missing_adr"
      return [] if duplicate_rule_open?(rule:)

      last_adr = KnowledgeLedger.kind_adr.order(created_at: :desc).first
      linked_kpis = {
        rule:,
        last_adr_at: last_adr&.created_at&.iso8601,
        stale_days: RUNBOOK_STALE_DAYS
      }
      ticket = create_ticket!(
        title: "Dept Health: No ADR created in #{RUNBOOK_STALE_DAYS}+ days",
        linked_kpis:,
        scope_level: :company
      )
      [detail_payload(ticket:, linked_kpis:)]
    end

    # ルール5: active サービスの weekly_dept 会議が MEETING_SKIP_DAYS 日以上未実施
    def detect_dept_meeting_skip
      active_service_ids.filter_map do |service_id|
        next if recent_weekly_meeting_exists?(service_id:)

        rule = "dept_meeting_skip"
        next if duplicate_rule_open?(rule:, service_id:)

        last_at = MeetingLedger.where(meeting_key: "weekly_dept", service_id:)
                               .maximum(:held_at)
        linked_kpis = {
          rule:,
          service_id:,
          last_meeting_at: last_at&.iso8601,
          skip_days: MEETING_SKIP_DAYS
        }
        ticket = create_ticket!(
          title: "Dept Health: No weekly meeting for service '#{service_id}' in #{MEETING_SKIP_DAYS}+ days",
          linked_kpis:,
          scope_level: :service,
          service_id:
        )
        detail_payload(ticket:, linked_kpis:)
      rescue StandardError => e
        Rails.logger.error("[DeptHealthChecker] dept_meeting_skip error for #{service_id}: #{e.message}")
        nil
      end.compact
    end

    def recent_weekly_meeting_exists?(service_id:)
      MeetingLedger.where(meeting_key: "weekly_dept", service_id:)
                   .where(held_at: MEETING_SKIP_DAYS.days.ago..)
                   .exists?
    end

    def active_service_ids
      @active_service_ids ||= ServiceLedger.where(status: :active).pluck(:service_id)
    rescue StandardError
      []
    end

    def create_ticket!(title:, linked_kpis:, scope_level:, service_id: nil)
      TicketLedger.create!(
        ticket_type: :improvement,
        title:,
        scope_level:,
        service_id:,
        source_meeting_type: :weekly,
        source_meeting: Ledgers::SystemMeetingProvider.for(kind: "dept_health_checker"),
        linked_kpis:,
        linked_artifacts: [],
        priority: :medium,
        status: :approved,
        assignee: "dept_health_checker",
        due_date: Date.current + IMPROVEMENT_DUE_DAYS.days,
        due_cycle: :weekly,
        skip_template_guard: true,
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
        operation: "dept_health_check",
        counts: { tickets_created: created.count, held_items: 0 },
        improvements: {
          detected: created.count,
          resolved: 0,
          details: created
        }
      )
    end

    def normalize_hash(value)
      value.is_a?(Hash) ? value : {}
    end
  end
end
