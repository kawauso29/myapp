require "rails_helper"

RSpec.describe "Phase 44e: enforce_template on TicketLedger", type: :model do
  let(:meeting) do
    md = MeetingDefinition.create!(
      meeting_key: "weekly_dept_enforce_tmpl_test",
      meeting_type: :weekly,
      scope_level: :service,
      service_id: "ai_sns",
      chair_role: "business_owner"
    )
    MeetingLedger.create!(
      meeting_definition: md,
      meeting_key: md.meeting_key,
      meeting_type: :weekly,
      scope_level: :service,
      service_id: "ai_sns",
      chair: md.chair_role,
      held_at: Time.current,
      status: :open,
      idempotency_key: "enforce-template-test-#{SecureRandom.hex(4)}"
    )
  end

  let(:valid_attrs) do
    {
      title: "Test ticket for enforce_template",
      ticket_type: :improvement,
      scope_level: :service,
      service_id: "ai_sns",
      status: :draft,
      priority: :medium,
      linked_kpis: ["kpi:test"],
      source_meeting: meeting,
      source_meeting_type: :weekly
    }
  end

  around do |example|
    original = TicketLedger.enforce_template
    example.run
  ensure
    TicketLedger.enforce_template = original
  end

  context "when enforce_template is OFF (default)" do
    before { TicketLedger.enforce_template = false }

    it "allows creation without template_id" do
      ticket = TicketLedger.new(valid_attrs)
      expect(ticket.save).to be true
    end
  end

  context "when enforce_template is ON" do
    before { TicketLedger.enforce_template = true }

    it "blocks creation without template_id" do
      ticket = TicketLedger.new(valid_attrs)
      expect(ticket.save).to be false
      expect(ticket.errors[:template_id]).to be_present
    end

    it "allows creation with template_id" do
      ticket = TicketLedger.new(valid_attrs.merge(template_id: "tmpl-improvement-999"))
      expect(ticket.save).to be true
    end

    it "allows creation when skip_template_guard is true" do
      ticket = TicketLedger.new(valid_attrs)
      ticket.skip_template_guard = true
      expect(ticket.save).to be true
    end
  end
end

RSpec.describe "Phase 44e: enforce_audit_reason on AuditDecisionLedger", type: :model do
  let(:meeting) do
    md = MeetingDefinition.create!(
      meeting_key: "audit_enforce_reason_test",
      meeting_type: :weekly,
      scope_level: :service,
      service_id: "ai_sns",
      chair_role: "business_owner"
    )
    MeetingLedger.create!(
      meeting_definition: md,
      meeting_key: md.meeting_key,
      meeting_type: :weekly,
      scope_level: :service,
      service_id: "ai_sns",
      chair: md.chair_role,
      held_at: Time.current,
      status: :open,
      idempotency_key: "enforce-audit-test-#{SecureRandom.hex(4)}"
    )
  end

  let(:ticket) do
    TicketLedger.create!(
      title: "Test audit target",
      ticket_type: :improvement,
      scope_level: :service,
      service_id: "ai_sns",
      status: :draft,
      priority: :medium,
      linked_kpis: ["kpi:test"],
      source_meeting: meeting,
      source_meeting_type: :weekly
    )
  end

  let(:base_attrs) do
    {
      target_ticket: ticket,
      audit_role: "exec_audit",
      scope_level: :service,
      decided_at: Time.current
    }
  end

  around do |example|
    original = AuditDecisionLedger.enforce_audit_reason
    example.run
  ensure
    AuditDecisionLedger.enforce_audit_reason = original
  end

  context "when enforce_audit_reason is OFF (default)" do
    before { AuditDecisionLedger.enforce_audit_reason = false }

    it "allows non-approval without reason_detail" do
      record = AuditDecisionLedger.new(base_attrs.merge(decision: :reject, reason_code: "scope_violation"))
      expect(record).to be_valid
    end
  end

  context "when enforce_audit_reason is ON" do
    before { AuditDecisionLedger.enforce_audit_reason = true }

    it "blocks non-approval without reason_detail" do
      record = AuditDecisionLedger.new(base_attrs.merge(decision: :reject, reason_code: "scope_violation"))
      expect(record).not_to be_valid
      expect(record.errors[:reason_detail]).to be_present
    end

    it "allows non-approval with reason_detail" do
      record = AuditDecisionLedger.new(base_attrs.merge(
                                         decision: :reject,
                                         reason_code: "scope_violation",
                                         reason_detail: "Scope violation detected in service boundary"
                                       ))
      expect(record).to be_valid
    end

    it "allows approval without reason_detail" do
      record = AuditDecisionLedger.new(base_attrs.merge(
                                         decision: :approve,
                                         reason_code: "approved_no_reservation"
                                       ))
      expect(record).to be_valid
    end

    it "allows bypass with skip_audit_reason_detail" do
      record = AuditDecisionLedger.new(base_attrs.merge(decision: :reject, reason_code: "scope_violation"))
      record.skip_audit_reason_detail = true
      expect(record).to be_valid
    end
  end
end
