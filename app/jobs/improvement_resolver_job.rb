class ImprovementResolverJob < ApplicationJob
  queue_as :default

  def perform
    result = Ledgers::ImprovementResolver.call
    return result if result[:resolved_tickets_count].zero?

    Ledgers::SlackNotifier.notify(
      operation: "resolve_improvements",
      counts: { tickets_created: result[:resolved_tickets_count], held_items: 0 },
      details: result[:resolved_tickets]
    )
    result
  end
end
