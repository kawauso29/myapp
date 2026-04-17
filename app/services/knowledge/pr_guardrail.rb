module Knowledge
  # Phase 37 / §20: high リスク / incident の改善起票に対して、
  # 対応する ADR または Runbook が KnowledgeLedger に存在することを要求する。
  #
  # 使い方:
  #   result = Knowledge::PrGuardrail.check(ticket: ticket)
  #   return head :unprocessable_entity unless result.passed?
  class PrGuardrail
    Result = Struct.new(:passed?, :missing_artifacts, keyword_init: true)

    REQUIRED_FOR_HIGH_RISK = %w[adr runbook].freeze

    def self.check(ticket:)
      new(ticket: ticket).check
    end

    def initialize(ticket:)
      @ticket = ticket
    end

    def check
      return Result.new(passed?: true, missing_artifacts: []) unless guardrail_applies?

      missing = REQUIRED_FOR_HIGH_RISK.reject { |kind| kind_exists?(kind) }
      Result.new(passed?: missing.empty?, missing_artifacts: missing)
    end

    private

    def guardrail_applies?
      %w[high].include?(@ticket.risk_level.to_s) ||
        @ticket.ticket_type.to_s == "investigation" ||
        @ticket.ticket_type.to_s == "tech_record"
    end

    def kind_exists?(kind)
      scope = KnowledgeLedger.where(kind: KnowledgeLedger.kinds[kind], status: KnowledgeLedger.statuses[:accepted])
      # 対応 ticket の service_id で絞り込む
      if @ticket.service_id.present?
        scope = scope.where("tags @> ?", { service_id: @ticket.service_id }.to_json)
          .or(KnowledgeLedger.where(kind: KnowledgeLedger.kinds[kind], status: KnowledgeLedger.statuses[:accepted], source_ticket_id: @ticket.id))
      end
      scope.exists?
    end
  end
end
