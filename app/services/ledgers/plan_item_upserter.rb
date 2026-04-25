module Ledgers
  # 複数サービス共通の「計画項目 → TicketLedger」 upserter。
  #
  # 旧来 `AiSnsPlanSync.upsert_ticket_for!` が `SERVICE_ID = "ai_sns"` を
  # ハードコードで内包していたものを、`service_id` を引数で受け取る形に汎用化した。
  # ai_sns 以外のサービス（ai_chat / voice_app など）が増えても本クラスを共有できる。
  #
  # マッピング規約（サービス共通）:
  #   - idempotency_key:   "#{service_id}_plan:#{item_key}"
  #   - source_meeting:    SystemMeetingProvider.for(kind: "#{service_id}_plan")
  #   - ticket_type:       "improvement"
  #   - scope_level:       :service / service_id
  #   - operating_lane:    :weekly_improvement
  #   - due_cycle:         :weekly
  #   - linked_kpis:       ["#{service_id}_plan:#{item_key}"]
  #   - status:            :todo→:draft / :in_progress→:executing / :done→:completed
  #   - priority:          そのまま
  #
  # ガード bypass:
  #   AI SNS 計画と同じく自動運用フロー扱いのため
  #   template / lane_capacity / pr_guardrail / stop の各 guard を skip する。
  class PlanItemUpserter
    TICKET_TYPE = "improvement".freeze

    STATUS_MAP = {
      "todo" => :draft,
      "in_progress" => :executing,
      "done" => :completed
    }.freeze

    class << self
      def call(service_id:, item_key:, title:, priority: :medium, category: nil,
               kpi_hypothesis: nil, notes: nil, status: :todo)
        raise ArgumentError, "service_id required" if service_id.to_s.strip.empty?
        raise ArgumentError, "item_key required" if item_key.to_s.strip.empty?
        raise ArgumentError, "title required" if title.to_s.strip.empty?

        new(service_id: service_id).upsert!(
          item_key: item_key, title: title, priority: priority, category: category,
          kpi_hypothesis: kpi_hypothesis, notes: notes, status: status
        )
      end

      def idempotency_key_for(service_id:, item_key:)
        "#{service_id}_plan:#{item_key}"
      end

      def linked_kpi_for(service_id:, item_key:)
        "#{service_id}_plan:#{item_key}"
      end

      def source_kind_for(service_id:)
        "#{service_id}_plan"
      end

      def normalize_status(status)
        STATUS_MAP[status.to_s] || status
      end
    end

    def initialize(service_id:)
      @service_id = service_id.to_s
    end

    def upsert!(item_key:, title:, priority:, category:, kpi_hypothesis:, notes:, status:)
      idem = self.class.idempotency_key_for(service_id: @service_id, item_key: item_key)
      ticket = TicketLedger.find_by(idempotency_key: idem) || TicketLedger.new(idempotency_key: idem)

      if ticket.new_record?
        meeting = SystemMeetingProvider.for(kind: self.class.source_kind_for(service_id: @service_id))
        ticket.source_meeting = meeting
        ticket.source_meeting_type = meeting.meeting_type
        ticket.linked_kpis = [ self.class.linked_kpi_for(service_id: @service_id, item_key: item_key) ]
      end

      attrs = {
        title: title,
        ticket_type: TICKET_TYPE,
        scope_level: :service,
        service_id: @service_id,
        operating_lane: :weekly_improvement,
        due_cycle: :weekly,
        priority: priority,
        status: self.class.normalize_status(status),
        kpi_hypothesis: kpi_hypothesis,
        improvement_pattern_key: category.presence
      }
      # notes は呼び出し側で明示指定された場合のみ上書きする（同 item_key 再呼出で
      # 既存 notes を消さないため。詳細は AiSnsPlanSync#upsert_ticket_for! 参照）。
      attrs[:notes] = notes if notes.present?

      ticket.assign_attributes(attrs)
      ticket.skip_template_guard = true
      ticket.skip_lane_capacity_guard = true
      ticket.skip_pr_guardrail = true
      ticket.skip_stop_guard = true
      ticket.save!
      ticket
    end
  end
end
