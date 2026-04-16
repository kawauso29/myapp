require "rails_helper"

RSpec.describe TicketLedger, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:ticket_type) }
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_presence_of(:scope_level) }
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_presence_of(:priority) }

    it "requires linked_kpis" do
      ticket = build(:ticket_ledger, linked_kpis: [])
      expect(ticket).not_to be_valid
      expect(ticket.errors[:linked_kpis]).to include("can't be blank")
    end
  end

  describe "enums" do
    it "defines status enum from spec" do
      expect(described_class.statuses.keys).to eq(%w[draft approved planned executing waiting_review completed cancelled overdue])
    end

    it "defines escalation_to enum" do
      expect(described_class.escalation_tos.keys).to include("monthly")
    end
  end

  describe "schema" do
    it "has phase 3 columns" do
      expect(described_class.column_names).to include("assignee", "due_date", "resolved_at")
    end
  end

  describe ".overdue_candidates" do
    it "returns only waiting_review tickets whose due_date is before today" do
      overdue_candidate = create(:ticket_ledger, status: :waiting_review, due_date: Date.current - 1.day)
      create(:ticket_ledger, status: :waiting_review, due_date: Date.current)
      create(:ticket_ledger, status: :approved, due_date: Date.current - 1.day)

      expect(described_class.overdue_candidates).to contain_exactly(overdue_candidate)
    end
  end

  describe "resolved_at automation" do
    it "sets resolved_at when status changes to approved" do
      ticket = create(:ticket_ledger, status: :draft, resolved_at: nil)

      expect { ticket.update!(status: :approved) }.to change { ticket.reload.resolved_at }.from(nil)
    end

    it "sets resolved_at when status changes to cancelled" do
      ticket = create(:ticket_ledger, status: :waiting_review, resolved_at: nil)

      expect { ticket.update!(status: :cancelled) }.to change { ticket.reload.resolved_at }.from(nil)
    end
  end
end
