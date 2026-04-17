module GithubMapping
  # §32-1: GitHub Project のフィールド定義。
  # §29.4 で定義された軸（scope_level / service_id / business_unit_id / ticket_type /
  # priority / status / linked_kpi / linked_meeting）を Project 用 JSON に変換する。
  class ProjectFieldMapper
    REQUIRED_FIELDS = %w[
      scope_level
      service_id
      business_unit_id
      ticket_type
      priority
      status
      linked_kpi
      linked_meeting
    ].freeze

    def self.map(ticket)
      new(ticket).map
    end

    def initialize(ticket)
      @ticket = ticket
    end

    def map
      {
        scope_level: ticket.scope_level,
        service_id: ticket.service_id,
        business_unit_id: ticket.business_owner,
        ticket_type: ticket.ticket_type,
        priority: ticket.priority,
        status: ticket.status,
        linked_kpi: Array(ticket.linked_kpis).first,
        linked_meeting: ticket.source_meeting_id
      }
    end

    private

    attr_reader :ticket
  end
end
