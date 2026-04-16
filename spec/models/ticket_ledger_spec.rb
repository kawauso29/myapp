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
    it "defines ticket_type enum" do
      expect(described_class.ticket_types.keys).to eq(%w[operations audit ops quarterly_review annual_plan improvement])
    end

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

  describe "補強10: effectiveness fields" do
    it "rejects effectiveness_score outside 0..1" do
      ticket = build(:ticket_ledger, effectiveness_score: 1.5)
      expect(ticket).not_to be_valid
      expect(ticket.errors[:effectiveness_score]).to be_present
    end

    it "rejects negative effectiveness_sample_size" do
      ticket = build(:ticket_ledger, effectiveness_sample_size: -1)
      expect(ticket).not_to be_valid
      expect(ticket.errors[:effectiveness_sample_size]).to be_present
    end

    describe ".effectiveness_for_pattern" do
      it "returns nil when sample size is below minimum" do
        2.times do
          create(:ticket_ledger,
                 ticket_type: "improvement",
                 improvement_pattern_key: "posting_frequency_up",
                 effectiveness_score: 0.5)
        end
        expect(described_class.effectiveness_for_pattern("posting_frequency_up")).to be_nil
      end

      it "returns average score once enough samples exist" do
        [ 0.2, 0.4, 0.6 ].each do |score|
          create(:ticket_ledger,
                 ticket_type: "improvement",
                 improvement_pattern_key: "prompt_tuning",
                 effectiveness_score: score)
        end
        expect(described_class.effectiveness_for_pattern("prompt_tuning")).to be_within(0.01).of(0.4)
      end
    end
  end

  describe "補強13: SLA fields" do
    it "auto-fills sla_breached_at when deadline is in the past" do
      ticket = build(:ticket_ledger, sla_deadline: 1.hour.ago)
      ticket.save!
      expect(ticket.sla_breached_at).to be_present
      expect(ticket).to be_sla_breached
    end

    it "does not mark breach when deadline is in the future" do
      ticket = create(:ticket_ledger, sla_deadline: 1.hour.from_now)
      expect(ticket.sla_breached_at).to be_nil
    end

    it "rejects sla_breached_at without sla_deadline" do
      ticket = build(:ticket_ledger, sla_breached_at: Time.current, sla_deadline: nil)
      expect(ticket).not_to be_valid
      expect(ticket.errors[:sla_breached_at]).to be_present
    end

    describe ".sla_breached" do
      it "returns only tickets whose sla_breached_at is set" do
        breached = create(:ticket_ledger, sla_deadline: 2.hours.ago)
        create(:ticket_ledger, sla_deadline: 1.hour.from_now)
        expect(described_class.sla_breached).to contain_exactly(breached)
      end
    end
  end
end
