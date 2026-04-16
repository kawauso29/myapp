class ImprovementDetectorJob < ApplicationJob
  queue_as :default

  def perform
    detector_result = Ledgers::ImprovementDetector.call
    resolver_result = Ledgers::ImprovementResolver.call

    {
      detected: detector_result[:detected] || detector_result["detected"] || 0,
      resolved: resolver_result[:resolved] || resolver_result["resolved"] || 0
    }
  end
end
