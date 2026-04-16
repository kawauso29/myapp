class TicketOverdueCheckJob < ApplicationJob
  queue_as :default

  def perform
    overdue_tickets = TicketLedger.overdue_candidates
    count = overdue_tickets.count
    overdue_tickets.find_each { |ticket| ticket.update!(status: :overdue) }
    Rails.logger.info("TicketOverdueCheckJob marked #{count} tickets as overdue")
    count
  end
end
