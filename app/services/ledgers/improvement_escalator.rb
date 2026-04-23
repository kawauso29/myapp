module Ledgers
  class ImprovementEscalator
    OPEN_STATUSES = %i[waiting_review overdue].freeze
    OVERDUE_AFTER_DAYS = 14
    MONTHLY_ESCALATION_AFTER_DAYS = 21
    QUARTERLY_ESCALATION_AFTER_DAYS = 45
    MONTHLY_REASON = "improvement_escalation_monthly".freeze
    QUARTERLY_REASON = "improvement_escalation_quarterly".freeze

    # meeting_key → cadence のマッピング（緊急会議作成時の idempotency_key 生成に使う）
    CADENCE_FOR_MEETING_KEY = {
      "monthly_ops" => :monthly,
      "quarterly_review" => :quarterly
    }.freeze

    def self.call
      new.call
    end

    def call
      result = base_result

      open_improvement_tickets.find_each do |ticket|
        mark_overdue_if_needed(ticket:, result:)
        escalate_if_needed(
          ticket:,
          result:,
          threshold_days: MONTHLY_ESCALATION_AFTER_DAYS,
          meeting_key: "monthly_ops",
          reason: MONTHLY_REASON,
          result_key: :escalated_monthly
        )
        escalate_if_needed(
          ticket:,
          result:,
          threshold_days: QUARTERLY_ESCALATION_AFTER_DAYS,
          meeting_key: "quarterly_review",
          reason: QUARTERLY_REASON,
          result_key: :escalated_quarterly
        )
      end

      notify_if_needed(result)
      result
    end

    private

    def base_result
      {
        operation: "escalate_improvements",
        overdue_marked: 0,
        escalated_monthly: 0,
        escalated_quarterly: 0,
        details: []
      }
    end

    def open_improvement_tickets
      TicketLedger.ticket_type_improvement.where(status: OPEN_STATUSES)
    end

    def mark_overdue_if_needed(ticket:, result:)
      return unless ticket.status_waiting_review?
      return unless ticket.created_at <= OVERDUE_AFTER_DAYS.days.ago

      ticket.update!(status: :overdue)
      result[:overdue_marked] += 1
      result[:details] << detail_payload(ticket:, action: "marked_overdue", reason: "over_14_days")
    end

    def escalate_if_needed(ticket:, result:, threshold_days:, meeting_key:, reason:, result_key:)
      return unless ticket_open?(ticket)
      return unless ticket.created_at <= threshold_days.days.ago

      meeting = latest_meeting(meeting_key:) || create_meeting_if_possible(meeting_key:)
      unless meeting
        result[:details] << detail_payload(ticket:, action: "escalation_deferred", reason:, meeting_key:)
        return
      end

      hold_items = Array(meeting.hold_items)
      return if hold_item_exists?(hold_items:, ticket_id: ticket.id, reason:)

      meeting.update!(hold_items: hold_items + [build_hold_item(ticket:, reason:, meeting_key:)])
      result[result_key] += 1
      result[:details] << detail_payload(ticket:, action: "escalated", reason:, meeting_key:, meeting_id: meeting.id)
    end

    def latest_meeting(meeting_key:)
      MeetingLedger.where(meeting_key:).order(held_at: :desc, id: :desc).first
    end

    def create_meeting_if_possible(meeting_key:)
      definition = MeetingDefinition.find_by(meeting_key:, scope_level: :company)
      return unless definition

      cadence = CADENCE_FOR_MEETING_KEY.fetch(meeting_key, :monthly)
      ikey = Ledgers::IdempotencyKey.for_meeting(prefix: meeting_key, cadence: cadence)

      # 同一スロット内に既存会議があればそれを返す（冪等化）
      existing = MeetingLedger.find_by(idempotency_key: ikey)
      return existing if existing

      MeetingLedger.create!(
        meeting_definition: definition,
        meeting_key: definition.meeting_key,
        meeting_type: definition.meeting_type,
        scope_level: definition.scope_level,
        chair: definition.chair_role,
        participants: definition.participant_roles,
        held_at: Time.current,
        status: :closed,
        idempotency_key: ikey
      )
    rescue ActiveRecord::RecordInvalid => e
      raise unless e.record.errors.of_kind?(:idempotency_key, :taken)

      MeetingLedger.find_by!(idempotency_key: ikey)
    end

    def hold_item_exists?(hold_items:, ticket_id:, reason:)
      hold_items.any? do |item|
        hash = normalize_hash(item)
        fetch_value(hash, :reason) == reason && fetch_value(hash, :ticket_ledger_id).to_i == ticket_id
      end
    end

    def build_hold_item(ticket:, reason:, meeting_key:)
      age_days = age_days(ticket)
      rule = linked_rule(ticket)
      {
        reason:,
        ticket_ledger_id: ticket.id,
        linked_kpis: { rule: },
        message: "Ticket##{ticket.id} #{ticket.title} unresolved #{age_days} days (rule=#{rule})",
        escalation_target: meeting_key
      }
    end

    def detail_payload(ticket:, action:, reason:, meeting_key: nil, meeting_id: nil)
      {
        action:,
        ticket_id: ticket.id,
        title: ticket.title,
        reason:,
        age_days: age_days(ticket),
        rule: linked_rule(ticket),
        meeting_key:,
        meeting_id:
      }.compact
    end

    def linked_rule(ticket)
      normalize_hash(ticket.linked_kpis)["rule"] || "unknown"
    end

    def age_days(ticket)
      ((Time.current - ticket.created_at) / 1.day).floor
    end

    def notify_if_needed(result)
      actions_count = result[:overdue_marked] + result[:escalated_monthly] + result[:escalated_quarterly]
      return if actions_count.zero?

      escalated_preview = Array(result[:details])
        .select { |item| fetch_value(normalize_hash(item), :action) == "escalated" }
        .first(3)
        .map do |item|
          hash = normalize_hash(item)
          {
            rule: fetch_value(hash, :rule),
            title: "ticket##{fetch_value(hash, :ticket_id)} #{fetch_value(hash, :title)} -> #{fetch_value(hash, :meeting_key)}"
          }
        end

      Ledgers::SlackNotifier.notify(
        operation: "escalate_improvements",
        counts: {
          tickets_created: 0,
          held_items: result[:escalated_monthly] + result[:escalated_quarterly]
        },
        overdue_marked: result[:overdue_marked],
        improvements: {
          detected: 0,
          resolved: 0,
          details: escalated_preview
        }
      )
    end

    def ticket_open?(ticket)
      ticket.status_waiting_review? || ticket.status_overdue?
    end

    def normalize_hash(value)
      case value
      when Hash
        value
      else
        {}
      end
    end

    def fetch_value(hash, key)
      hash[key] || hash[key.to_s]
    end
  end
end
