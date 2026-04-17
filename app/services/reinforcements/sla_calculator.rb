module Reinforcements
  # Phase 23 / 補強13: ticket_ledgers.sla_deadline / sla_breach_action を自動計算する。
  # 既定マトリクスは §33.3 補強13 の表に準拠する（月次運営会議で見直し可能）。
  class SlaCalculator
    # 行キー: [scope_level, due_cycle] / 値: {days:, action:}
    # `any` は scope_level 問わずのワイルドカードとして扱う。
    DEFAULT_MATRIX = {
      %i[service weekly]      => { days: 7,  action: :auto_escalate },
      %i[service monthly]     => { days: 30, action: :auto_reject },
      %i[portfolio monthly]   => { days: 30, action: :auto_escalate },
      %i[company quarterly]   => { days: 90, action: :audit_open },
      [ :any, :daily ]        => { days: 2,  action: :auto_reject }
    }.freeze

    def self.calculate_for(ticket, now: Time.current)
      scope = ticket.scope_level&.to_sym
      cycle = ticket.due_cycle&.to_sym
      return nil if cycle.blank?

      row = DEFAULT_MATRIX[[ scope, cycle ]] || DEFAULT_MATRIX[[ :any, cycle ]]
      return nil unless row

      {
        sla_deadline: now + row[:days].days,
        sla_breach_action: row[:action]
      }
    end

    # ticket に deadline/action を適用して保存する。既に breach 済みなら上書きしない。
    def self.apply!(ticket, now: Time.current)
      return ticket if ticket.sla_breached_at.present?

      attrs = calculate_for(ticket, now: now)
      return ticket unless attrs

      ticket.update!(attrs)
      ticket
    end
  end
end
