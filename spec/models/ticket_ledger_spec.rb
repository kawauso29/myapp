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
    it "defines ticket_type enum with 11 §17 categories + legacy types" do
      keys = described_class.ticket_types.keys
      # §17 の 11 種が全部含まれる
      expect(keys).to include(
        "initiative", "investigation", "audit", "hr", "customer_notice",
        "tech_record", "org_change", "exec_plan",
        "service_launch", "service_shutdown", "service_merge"
      )
      # 既存互換: 後方互換のために残している旧来のキーも含まれる
      expect(keys).to include("operations", "ops", "quarterly_review", "annual_plan", "improvement", "service_pivot")
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

  describe "Phase 30 補強1: idempotency_key" do
    it "allows creation with nil idempotency_key" do
      record = create(:ticket_ledger, idempotency_key: nil)
      expect(record).to be_persisted
      expect(record.idempotency_key).to be_nil
    end

    it "persists a unique idempotency_key when provided" do
      key = "improvement:pattern-x:#{Date.current}"
      create(:ticket_ledger, idempotency_key: key)
      duplicate = build(:ticket_ledger, idempotency_key: key)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:idempotency_key]).to be_present
    end
  end

  describe "Phase 33 補強7: stop guard" do
    around do |example|
      original = described_class.enforce_stop_guard
      described_class.enforce_stop_guard = true
      example.run
    ensure
      described_class.enforce_stop_guard = original
    end

    it "blocks ticket creation when an active company-scope stop exists" do
      create(:stop_ledger, scope_level: :company, service_id: nil,
                           trigger_type: :error_spike, status: :active,
                           started_at: 1.minute.ago)

      ticket = build(:ticket_ledger, scope_level: :service, service_id: "ai_sns")
      expect(ticket.save).to be false
      expect(ticket.errors[:base].join).to include("blocked by active stops")
    end

    it "allows creation when skip_stop_guard is set" do
      create(:stop_ledger, scope_level: :company, service_id: nil,
                           trigger_type: :error_spike, status: :active,
                           started_at: 1.minute.ago)

      ticket = build(:ticket_ledger, scope_level: :service, service_id: "ai_sns")
      ticket.skip_stop_guard = true
      expect(ticket.save).to be true
    end

    it "allows creation when no active stop exists" do
      ticket = build(:ticket_ledger, scope_level: :service, service_id: "ai_sns")
      expect(ticket.save).to be true
    end

    it "allows investigation ticket even when stop is active (bypass by ticket_type)" do
      create(:stop_ledger, scope_level: :company, service_id: nil,
                           trigger_type: :error_spike, status: :active,
                           started_at: 1.minute.ago)

      ticket = build(:ticket_ledger, ticket_type: :investigation, scope_level: :service, service_id: "ai_sns")
      expect(ticket.save).to be true
    end

    it "allows quarterly_review summary ticket even when stop is active" do
      create(:stop_ledger, scope_level: :company, service_id: nil,
                           trigger_type: :kpi_breach, status: :active,
                           started_at: 1.minute.ago)

      ticket = build(:ticket_ledger, ticket_type: :quarterly_review, scope_level: :company, service_id: nil)
      expect(ticket.save).to be true
    end
  end

  describe "Phase 36/37: warn_lane_capacity / warn_pr_guardrail" do
    it "logs a warning when lane usage is at or over cap" do
      # Create cap
      LaneCapacityCap.create!(scope_level: :service, service_id: "ai_sns", operating_lane: :weekly_improvement, wip_cap: 1)
      # Use up the cap
      create(:ticket_ledger, operating_lane: :weekly_improvement, scope_level: :service, service_id: "ai_sns", status: :waiting_review)

      original = described_class.warn_lane_capacity
      described_class.warn_lane_capacity = true

      expect(Rails.logger).to receive(:warn).with(a_string_including("[LaneCapacityGuard] over cap"))

      create(:ticket_ledger, operating_lane: :weekly_improvement, scope_level: :service, service_id: "ai_sns", status: :waiting_review)
    ensure
      described_class.warn_lane_capacity = original
    end

    it "logs a warning when high-risk ticket is missing ADR/runbook" do
      original = described_class.warn_pr_guardrail
      described_class.warn_pr_guardrail = true

      expect(Rails.logger).to receive(:warn).with(a_string_including("[PrGuardrail] missing artifacts"))

      create(:ticket_ledger, ticket_type: :investigation, risk_level: :high, scope_level: :service, service_id: "ai_sns")
    ensure
      described_class.warn_pr_guardrail = original
    end
  end

  describe "Phase 35 補強9: template_id" do
    it "allows nil template_id" do
      expect(create(:ticket_ledger, template_id: nil)).to be_persisted
    end

    it "rejects malformed template_id" do
      ticket = build(:ticket_ledger, template_id: "not-valid")
      expect(ticket).not_to be_valid
      expect(ticket.errors[:template_id]).to be_present
    end

    it "accepts the canonical tmpl-<type>-<id> format" do
      ticket = build(:ticket_ledger, template_id: "tmpl-improvement-42")
      expect(ticket).to be_valid
    end

    it "enforces uniqueness of template_id" do
      create(:ticket_ledger, template_id: "tmpl-improvement-1001")
      dup = build(:ticket_ledger, template_id: "tmpl-improvement-1001")
      expect(dup).not_to be_valid
      expect(dup.errors[:template_id]).to be_present
    end
  end

  describe "Phase 36 enforce_lane_capacity" do
    around do |example|
      original_enforce = described_class.enforce_lane_capacity
      described_class.enforce_lane_capacity = true
      example.run
    ensure
      described_class.enforce_lane_capacity = original_enforce
    end

    it "blocks ticket creation when lane WIP cap is reached" do
      create(:lane_capacity_cap,
             scope_level: :service,
             service_id: "ai_sns",
             operating_lane: :weekly_improvement,
             wip_cap: 1)
      create(:ticket_ledger,
             operating_lane: :weekly_improvement,
             status: :approved,
             service_id: "ai_sns")

      ticket = build(:ticket_ledger,
                     operating_lane: :weekly_improvement,
                     status: :approved,
                     service_id: "ai_sns")
      expect(ticket.save).to be false
      expect(ticket.errors[:base].join).to include("lane capacity exceeded")
    end

    it "can be bypassed with skip_lane_capacity_guard = true" do
      create(:lane_capacity_cap,
             scope_level: :service,
             service_id: "ai_sns",
             operating_lane: :weekly_improvement,
             wip_cap: 1)
      create(:ticket_ledger,
             operating_lane: :weekly_improvement,
             status: :approved,
             service_id: "ai_sns")

      ticket = build(:ticket_ledger,
                     operating_lane: :weekly_improvement,
                     status: :approved,
                     service_id: "ai_sns")
      ticket.skip_lane_capacity_guard = true
      expect(ticket.save).to be true
    end
  end

  describe "Phase 37 enforce_pr_guardrail" do
    around do |example|
      original_enforce = described_class.enforce_pr_guardrail
      described_class.enforce_pr_guardrail = true
      example.run
    ensure
      described_class.enforce_pr_guardrail = original_enforce
    end

    it "blocks high-risk ticket when ADR/runbook are missing" do
      ticket = build(:ticket_ledger,
                     ticket_type: :investigation,
                     risk_level: :high,
                     scope_level: :service,
                     service_id: "ai_sns")
      expect(ticket.save).to be false
      expect(ticket.errors[:base].join).to include("pr_guardrail missing artifacts")
    end

    it "allows creation when ADR and runbook exist for the service" do
      create(:knowledge_ledger, kind: :adr, status: :accepted,
             tags: { service_id: "ai_sns" })
      create(:knowledge_ledger, kind: :runbook, status: :accepted,
             tags: { service_id: "ai_sns" })

      ticket = build(:ticket_ledger,
                     ticket_type: :investigation,
                     risk_level: :high,
                     scope_level: :service,
                     service_id: "ai_sns")
      expect(ticket.save).to be true
    end
  end
end
