class ImprovementDetectorJob < ApplicationJob
  queue_as :default

  def perform
    detector_result = Ledgers::ImprovementDetector.call
    resolver_result = Ledgers::ImprovementResolver.call

    {
      detected: detector_result.fetch(:detected, 0),
      resolved: resolver_result.fetch(:resolved, 0)
    }
  end
end
