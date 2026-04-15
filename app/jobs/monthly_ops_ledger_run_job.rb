class MonthlyOpsLedgerRunJob < ApplicationJob
  queue_as :default

  def perform(resolution_map: {})
    Ledgers::MonthlyOpsRunner.call(resolution_map:)
  end
end
