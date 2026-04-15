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
      expect(described_class.statuses.keys).to eq(%w[draft approved planned executing waiting_review completed cancelled])
    end

    it "defines escalation_to enum" do
      expect(described_class.escalation_tos.keys).to include("monthly")
    end
  end
end
