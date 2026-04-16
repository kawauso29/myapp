require "rails_helper"

RSpec.describe TicketOverdueCheckJob, type: :job do
  describe "#perform" do
    it "marks overdue waiting_review tickets as overdue" do
      overdue_ticket = create(:ticket_ledger, status: :waiting_review, due_date: Date.current - 1.day)
      create(:ticket_ledger, status: :waiting_review, due_date: Date.current)
      create(:ticket_ledger, status: :approved, due_date: Date.current - 1.day)
      allow(Ledgers::SlackNotifier).to receive(:notify)

      expect(described_class.perform_now).to eq(1)
      expect(overdue_ticket.reload).to be_status_overdue
      expect(Ledgers::SlackNotifier).to have_received(:notify).with(operation: "check_overdue", overdue_marked: 1)
    end

    it "does not notify when no tickets are marked overdue" do
      create(:ticket_ledger, status: :waiting_review, due_date: Date.current)
      allow(Ledgers::SlackNotifier).to receive(:notify)

      expect(described_class.perform_now).to eq(0)
      expect(Ledgers::SlackNotifier).not_to have_received(:notify)
    end
  end
end
