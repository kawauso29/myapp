class ImprovementEscalationJob < ApplicationJob
  queue_as :default

  def perform
    Ledgers::ImprovementEscalator.call
  end
end
