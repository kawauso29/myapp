class UiCheckLedgerRunJob < ApplicationJob
  include Ledgers::JobIdempotency
  queue_as :default

  SERVICE_ID = "ai_sns".freeze

  # Phase 42 / UI伴走管理: AI SNS UI サービスの定期チェックサイクルを実行する。
  # WeeklyDeptRunner を ai_sns_ui に対して呼び出し、画面稼働率・クラッシュ率等の
  # UI 固有 KPI を台帳に記録する。2日ごとに recurring.yml から起動される。
  def perform(ticket_inputs: nil)
    self.class.with_job_idempotency("ui_check:#{SERVICE_ID}:#{Date.current.iso8601}") do
      meeting = Ledgers::WeeklyDeptRunner.call(
        service_id: SERVICE_ID,
        ticket_inputs: ticket_inputs
      )
      payload = JSON.parse(Ledgers::RunOutputFormatter.format(meeting:, operation: "ui_check"))
      Ledgers::SlackNotifier.notify(payload)
      meeting
    end
  end
end
