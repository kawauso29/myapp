class WeeklyDeptLedgerRunJob < ApplicationJob
  include Ledgers::JobIdempotency
  queue_as :default

  def perform(service_id = nil, ticket_inputs: nil, **options)
    resolved_service_id = extract_option(options, :service_id) || service_id || "ai_sns"
    self.class.with_job_idempotency("weekly_dept:#{resolved_service_id}:#{Ledgers::TimeAxis.slot_token(:weekly)}") do
      begin
        meeting = Ledgers::WeeklyDeptRunner.call(
          service_id: resolved_service_id,
          ticket_inputs: extract_option(options, :ticket_inputs) || ticket_inputs
        )
        payload = JSON.parse(Ledgers::RunOutputFormatter.format(meeting:, operation: "weekly_dept"))
        Ledgers::SlackNotifier.notify(payload)
        meeting
      rescue ActiveRecord::RecordInvalid => e
        raise unless duplicate_meeting_idempotency_error?(e)

        Rails.logger.info("[WeeklyDeptLedgerRunJob] skip duplicate meeting by idempotency_key")
        nil
      end
    end
  end

  private

  def extract_option(options, key)
    options[key] || options[key.to_s]
  end

  def duplicate_meeting_idempotency_error?(error)
    record = error.record
    record.is_a?(MeetingLedger) && record.errors.of_kind?(:idempotency_key, :taken)
  end
end
