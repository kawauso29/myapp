module Ledgers
  # PR1（並走）: DevInitiative の状態を TicketLedger にミラーリングする。
  #
  # 目的:
  #   `DevInitiative`（AI SNS 改善計画項目）から `TicketLedger`（運営 OS の正本台帳）へ
  #   並走で書き込みを写すことで、PR2 で読み取り側を `TicketLedger` に切替えられる
  #   状態を作る。本サービスは PR1 では DevInitiative → TicketLedger の単方向のみ。
  #
  # マッピング:
  #   - idempotency_key:   "ai_sns_plan:#{item_key}"   （旧 external_ref 役）
  #   - source_meeting:    SystemMeetingProvider.for(kind: "ai_sns_plan")
  #   - ticket_type:       "improvement"               （§17 / 補強10 と整合）
  #   - scope_level:       :service / service_id="ai_sns"
  #   - operating_lane:    :weekly_improvement
  #   - due_cycle:         :weekly                     （圧縮 weekly = 4h）
  #   - linked_kpis:       ["ai_sns_plan:#{item_key}"]（空配列 NG のため placeholder）
  #   - status:            todo→draft / in_progress→executing / done→completed
  #   - priority:          そのまま（low/medium/high の enum 値が一致）
  #   - title / pr_branch / kpi_hypothesis / kpi_result / due_date(=completed_at): mirror
  #
  # ガード bypass:
  #   AI SNS 計画は自動運用フローのためテンプレート / lane_capacity / pr_guardrail は
  #   skip する（既存 Runner 系と同じポリシー）。
  class AiSnsPlanSync
    SERVICE_ID = "ai_sns".freeze
    TICKET_TYPE = "improvement".freeze
    SOURCE_KIND = "ai_sns_plan".freeze

    STATUS_MAP = {
      "todo" => :draft,
      "in_progress" => :executing,
      "done" => :completed
    }.freeze

    class << self
      # @param initiative [DevInitiative]
      # @return [TicketLedger]
      def call(initiative)
        new(initiative).call
      end

      def idempotency_key_for(item_key)
        "ai_sns_plan:#{item_key}"
      end

      def linked_kpi_for(item_key)
        "ai_sns_plan:#{item_key}"
      end

      # PR3 で導入 / PR4 で notes を TicketLedger 側に正規化。
      # TicketLedger を正本として AI SNS 計画項目を新規作成する。
      # 旧来の `DevInitiative.create!` の代替（plan_review.yml の Copilot 指示で利用）。
      #
      # @param item_key [String] AI SNS 計画 ID（例: "B2"）。idempotency_key の一意キー。
      # @param title [String] 項目タイトル。
      # @param priority [Symbol, String] :high / :medium / :low。
      # @param category [String, nil] improvement_pattern_key にマップ。
      # @param kpi_hypothesis [String, nil] KPI 仮説（任意）。
      # @param notes [String, nil] 補足メモ（任意）。TicketLedger.notes に直接書き込む。
      # @param status [Symbol] :todo / :in_progress / :done もしくは TicketLedger.status enum。
      # @return [TicketLedger]
      def create_plan_item!(item_key:, title:, priority: :medium, category: nil,
                            kpi_hypothesis: nil, notes: nil, status: :todo)
        raise ArgumentError, "item_key required" if item_key.to_s.strip.empty?
        raise ArgumentError, "title required" if title.to_s.strip.empty?

        upsert_ticket_for!(
          item_key: item_key, title: title, priority: priority, category: category,
          kpi_hypothesis: kpi_hypothesis, notes: notes, status: status
        )
      end

      def upsert_ticket_for!(item_key:, title:, priority:, category:, kpi_hypothesis:, notes: nil, status:)
        idem = idempotency_key_for(item_key)
        ticket = TicketLedger.find_by(idempotency_key: idem) || TicketLedger.new(idempotency_key: idem)

        if ticket.new_record?
          meeting = SystemMeetingProvider.for(kind: SOURCE_KIND)
          ticket.source_meeting = meeting
          ticket.source_meeting_type = meeting.meeting_type
          ticket.linked_kpis = [ linked_kpi_for(item_key) ]
        end

        attrs = {
          title: title,
          ticket_type: TICKET_TYPE,
          scope_level: :service,
          service_id: SERVICE_ID,
          operating_lane: :weekly_improvement,
          due_cycle: :weekly,
          priority: priority,
          status: normalize_status(status),
          kpi_hypothesis: kpi_hypothesis,
          improvement_pattern_key: category.presence
        }
        # notes は呼び出し側で明示指定された場合のみ上書き（後続の mirror 経由で別値が
        # 来る可能性があるため、nil は無視して既存値を保持する）。
        attrs[:notes] = notes if notes.present?
        ticket.assign_attributes(attrs)
        ticket.skip_template_guard = true
        ticket.skip_lane_capacity_guard = true
        ticket.skip_pr_guardrail = true
        ticket.skip_stop_guard = true
        ticket.save!
        ticket
      end

      def normalize_status(status)
        case status.to_s
        when "todo" then :draft
        when "in_progress" then :executing
        when "done" then :completed
        else status
        end
      end
    end

    def initialize(initiative)
      @initiative = initiative
    end

    def call
      ticket = TicketLedger.find_by(idempotency_key: idempotency_key)
      ticket ? update_ticket!(ticket) : create_ticket!
    end

    private

    attr_reader :initiative

    def idempotency_key
      self.class.idempotency_key_for(initiative.item_key)
    end

    def linked_kpi
      self.class.linked_kpi_for(initiative.item_key)
    end

    def mapped_status
      STATUS_MAP[initiative.status.to_s] || :draft
    end

    def mapped_attributes
      {
        title: initiative.title,
        ticket_type: TICKET_TYPE,
        scope_level: :service,
        service_id: SERVICE_ID,
        operating_lane: :weekly_improvement,
        due_cycle: :weekly,
        priority: initiative.priority,
        status: mapped_status,
        pr_branch: initiative.pr_branch,
        kpi_hypothesis: initiative.kpi_hypothesis,
        kpi_result: initiative.kpi_result,
        notes: initiative.notes,
        due_date: initiative.completed_at&.to_date,
        improvement_pattern_key: initiative.category.presence
      }
    end

    def create_ticket!
      meeting = SystemMeetingProvider.for(kind: SOURCE_KIND)
      ticket = TicketLedger.new(mapped_attributes.merge(
        idempotency_key: idempotency_key,
        source_meeting: meeting,
        source_meeting_type: meeting.meeting_type,
        linked_kpis: [ linked_kpi ]
      ))
      ticket.skip_template_guard = true
      ticket.skip_lane_capacity_guard = true
      ticket.skip_pr_guardrail = true
      ticket.skip_stop_guard = true
      ticket.save!
      ticket
    end

    def update_ticket!(ticket)
      ticket.assign_attributes(mapped_attributes)
      ticket.linked_kpis = [ linked_kpi ] if ticket.linked_kpis.blank?
      ticket.save! if ticket.changed?
      ticket
    end
  end
end
