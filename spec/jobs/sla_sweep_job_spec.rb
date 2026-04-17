require "rails_helper"

RSpec.describe SlaSweepJob, type: :job do
  describe "#perform" do
    it "applies SLA deadline to tickets without one" do
      ticket = create(:ticket_ledger, status: :approved, due_cycle: :weekly, scope_level: :service, sla_deadline: nil)

      result = described_class.new.perform

      expect(ticket.reload.sla_deadline).to be_present
      expect(result[:evaluated]).to be >= 1
      expect(result[:applied]).to be >= 1
    end

    it "marks breach when deadline already passed" do
      ticket = create(:ticket_ledger, status: :waiting_review, due_cycle: :weekly, scope_level: :service)
      ticket.update_columns(sla_deadline: 1.day.ago, sla_breached_at: nil)

      result = described_class.new.perform

      expect(ticket.reload.sla_breached_at).to be_present
      expect(result[:breached]).to be >= 1
    end

    it "does not touch tickets already breached" do
      ticket = create(:ticket_ledger, status: :approved, due_cycle: :weekly, scope_level: :service)
      # bypass before_save guard to set deadline without breach
      ticket.update_columns(sla_deadline: 2.days.ago, sla_breached_at: 2.days.ago)

      described_class.new.perform
      expect(ticket.reload.sla_breached_at.to_date).to eq(2.days.ago.to_date)
    end

    it "ignores completed tickets" do
      ticket = create(:ticket_ledger, status: :approved, due_cycle: :weekly, scope_level: :service)
      ticket.update_columns(status: TicketLedger.statuses[:completed], sla_deadline: nil)

      described_class.new.perform
      expect(ticket.reload.sla_deadline).to be_nil
    end
  end
end
