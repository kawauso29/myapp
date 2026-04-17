class SlaSweepJob < ApplicationJob
  queue_as :default

  # 補強13: 未完了チケットの sla_deadline を計算し、超過分は sla_breached_at を立てる。
  # `before_save :mark_sla_breach` が発火するため、`apply!` → `touch` で救済する。
  # 1時間ごとに走らせ、`waiting_review` / `approved` / `planned` / `executing` のみを対象とする。
  TARGET_STATUSES = %i[approved planned executing waiting_review].freeze

  def perform
    results = { evaluated: 0, applied: 0, breached: 0 }

    TicketLedger
      .where(status: TARGET_STATUSES)
      .find_each do |ticket|
        results[:evaluated] += 1

        if ticket.sla_deadline.blank?
          Reinforcements::SlaCalculator.apply!(ticket)
          results[:applied] += 1 if ticket.sla_deadline.present?
        elsif ticket.sla_breached_at.blank? && ticket.sla_deadline < Time.current
          ticket.update_columns(sla_breached_at: Time.current, updated_at: Time.current)
          results[:breached] += 1 if ticket.reload.sla_breached_at.present?
        end
      end

    results
  end
end
