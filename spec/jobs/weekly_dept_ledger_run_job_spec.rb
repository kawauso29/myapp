require "rails_helper"

RSpec.describe WeeklyDeptLedgerRunJob, type: :job do
  describe "#perform" do
    let(:meeting) { instance_double(MeetingLedger) }
    let(:payload) { { "operation" => "weekly_dept" } }

    it "calls weekly runner and notifies slack" do
      allow(Ledgers::WeeklyDeptRunner).to receive(:call).and_return(meeting)
      allow(Ledgers::RunOutputFormatter).to receive(:format).and_return(payload.to_json)
      allow(Ledgers::SlackNotifier).to receive(:notify)

      described_class.perform_now(service_id: "ai_sns")

      expect(Ledgers::WeeklyDeptRunner).to have_received(:call).with(service_id: "ai_sns", ticket_inputs: nil)
      expect(Ledgers::RunOutputFormatter).to have_received(:format).with(meeting:, operation: "weekly_dept")
      expect(Ledgers::SlackNotifier).to have_received(:notify).with(payload)
    end

    it "skips duplicate idempotency_key errors without raising" do
      duplicate = MeetingLedger.new
      duplicate.errors.add(:idempotency_key, :taken)
      duplicate_error = ActiveRecord::RecordInvalid.new(duplicate)

      allow(Ledgers::WeeklyDeptRunner).to receive(:call).and_raise(duplicate_error)
      allow(Ledgers::SlackNotifier).to receive(:notify)

      expect { described_class.perform_now(service_id: "ai_sns") }.not_to raise_error
      expect(Ledgers::SlackNotifier).not_to have_received(:notify)
    end

    it "re-raises non-idempotency validation errors" do
      invalid = MeetingLedger.new
      invalid.errors.add(:held_at, :blank)
      invalid_error = ActiveRecord::RecordInvalid.new(invalid)

      allow(Ledgers::WeeklyDeptRunner).to receive(:call).and_raise(invalid_error)

      expect { described_class.perform_now(service_id: "ai_sns") }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end
