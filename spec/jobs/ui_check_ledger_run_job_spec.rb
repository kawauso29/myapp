require "rails_helper"

RSpec.describe UiCheckLedgerRunJob, type: :job do
  describe "#perform" do
    let(:meeting) { instance_double(MeetingLedger) }
    let(:payload) { { "operation" => "ui_check" } }

    it "calls weekly runner for ai_sns_ui and notifies slack" do
      allow(Ledgers::WeeklyDeptRunner).to receive(:call).and_return(meeting)
      allow(Ledgers::RunOutputFormatter).to receive(:format).and_return(payload.to_json)
      allow(Ledgers::SlackNotifier).to receive(:notify)

      described_class.perform_now

      expect(Ledgers::WeeklyDeptRunner).to have_received(:call).with(service_id: "ai_sns", ticket_inputs: nil, meeting_key: "ui_check")
      expect(Ledgers::RunOutputFormatter).to have_received(:format).with(meeting:, operation: "ui_check")
      expect(Ledgers::SlackNotifier).to have_received(:notify).with(payload)
    end

    it "accepts custom ticket_inputs" do
      custom_inputs = [ { ticket_type: "tech_record", title: "UI spec review", linked_kpis: [ "kpi:ai_sns_ui_screen_coverage" ], audit_ok: true } ]
      allow(Ledgers::WeeklyDeptRunner).to receive(:call).and_return(meeting)
      allow(Ledgers::RunOutputFormatter).to receive(:format).and_return(payload.to_json)
      allow(Ledgers::SlackNotifier).to receive(:notify)

      described_class.perform_now(ticket_inputs: custom_inputs)

      expect(Ledgers::WeeklyDeptRunner).to have_received(:call).with(service_id: "ai_sns", ticket_inputs: custom_inputs, meeting_key: "ui_check")
    end

    it "skips duplicate idempotency_key errors without raising" do
      duplicate = MeetingLedger.new
      duplicate.errors.add(:idempotency_key, :taken)
      duplicate_error = ActiveRecord::RecordInvalid.new(duplicate)

      allow(Ledgers::WeeklyDeptRunner).to receive(:call).and_raise(duplicate_error)
      allow(Ledgers::SlackNotifier).to receive(:notify)

      expect { described_class.perform_now }.not_to raise_error
      expect(Ledgers::SlackNotifier).not_to have_received(:notify)
    end

    it "re-raises non-idempotency validation errors" do
      invalid = MeetingLedger.new
      invalid.errors.add(:held_at, :blank)
      invalid_error = ActiveRecord::RecordInvalid.new(invalid)

      allow(Ledgers::WeeklyDeptRunner).to receive(:call).and_raise(invalid_error)

      expect { described_class.perform_now }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end
