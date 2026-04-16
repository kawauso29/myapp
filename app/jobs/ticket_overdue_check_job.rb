class TicketOverdueCheckJob < ApplicationJob
  queue_as :default

  def perform
    overdue_tickets = TicketLedger.overdue_candidates.to_a
    count = overdue_tickets.size
    overdue_tickets.each { |ticket| ticket.update!(status: :overdue) }
    Rails.logger.info("TicketOverdueCheckJob marked #{count} tickets as overdue")
    count
  end
end
