class ImprovementDetectorJob < ApplicationJob
  queue_as :default

  def perform
    result = Ledgers::ImprovementDetector.call

    {
      detected: result.fetch(:detected, 0)
    }
  end
end
