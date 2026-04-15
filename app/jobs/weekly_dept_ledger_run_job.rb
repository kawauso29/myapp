class WeeklyDeptLedgerRunJob < ApplicationJob
  queue_as :default

  def perform(service_id:, ticket_inputs: nil)
    Ledgers::WeeklyDeptRunner.call(service_id:, ticket_inputs:)
  end
end
