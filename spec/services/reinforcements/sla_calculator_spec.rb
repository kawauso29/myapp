require "rails_helper"

RSpec.describe Reinforcements::SlaCalculator do
  describe ".calculate_for" do
    it "returns nil when due_cycle is blank" do
      ticket = build(:ticket_ledger, due_cycle: nil)
      expect(described_class.calculate_for(ticket)).to be_nil
    end

    it "returns service/weekly → 7 days + auto_escalate" do
      ticket = build(:ticket_ledger, scope_level: :service, due_cycle: :weekly)
      now = Time.zone.local(2026, 4, 1, 0, 0)
      result = described_class.calculate_for(ticket, now: now)
      expect(result[:sla_breach_action]).to eq(:auto_escalate)
      expect(result[:sla_deadline]).to eq(now + 7.days)
    end

    it "falls back to any/daily row when scope doesn't match" do
      ticket = build(:ticket_ledger, scope_level: :portfolio, due_cycle: :daily)
      result = described_class.calculate_for(ticket)
      expect(result[:sla_breach_action]).to eq(:auto_reject)
    end
  end

  describe ".apply!" do
    it "updates ticket with deadline and action" do
      ticket = create(:ticket_ledger, scope_level: :service, due_cycle: :weekly)
      described_class.apply!(ticket)
      ticket.reload
      expect(ticket.sla_deadline).to be_present
      expect(ticket.sla_breach_action).to eq("auto_escalate")
    end

    it "does not overwrite already breached tickets" do
      ticket = create(:ticket_ledger,
                      scope_level: :service,
                      due_cycle: :weekly,
                      sla_deadline: 2.hours.ago,
                      sla_breached_at: 1.hour.ago)
      original_deadline = ticket.sla_deadline
      described_class.apply!(ticket)
      expect(ticket.reload.sla_deadline).to be_within(1.second).of(original_deadline)
    end
  end
end
