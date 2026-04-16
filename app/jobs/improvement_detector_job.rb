class ImprovementDetectorJob < ApplicationJob
  queue_as :default

  def perform
    result = Ledgers::ImprovementDetector.call
    return result if result[:created_tickets_count].zero?

    Ledgers::SlackNotifier.notify(
      operation: "detect_improvements",
      counts: { tickets_created: result[:created_tickets_count], held_items: 0 },
      details: result[:created_tickets]
    )
    result
  end
end
