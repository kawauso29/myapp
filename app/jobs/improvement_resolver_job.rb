class ImprovementResolverJob < ApplicationJob
  queue_as :default

  def perform
    result = Ledgers::ImprovementResolver.call
    return result if result[:resolved].to_i.zero?

    Ledgers::SlackNotifier.notify(
      operation: "resolve_improvements",
      counts: { tickets_created: result[:resolved], held_items: 0 },
      details: result[:details]
    )
    result
  end
end
