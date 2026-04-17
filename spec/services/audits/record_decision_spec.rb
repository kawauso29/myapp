require "rails_helper"

RSpec.describe Audits::RecordDecision do
  let(:ticket) { create(:ticket_ledger, status: :waiting_review, ticket_type: :improvement) }

  it "creates an approval record and transitions the ticket" do
    result = described_class.call(
      ticket: ticket,
      decision: :approve,
      reason_code: "approved_no_reservation",
      audit_role: "audit_board"
    )

    expect(result.decision).to be_decision_approve
    expect(result.ticket).to be_status_approved
  end

  it "creates a rejection record and cancels the ticket" do
    result = described_class.call(
      ticket: ticket,
      decision: :reject,
      reason_code: "security_risk",
      audit_role: "audit_board",
      reason_detail: "contains untrusted input path"
    )

    expect(result.decision).to be_decision_reject
    expect(result.decision.reason_detail).to eq("contains untrusted input path")
    expect(result.ticket).to be_status_cancelled
  end

  it "request_changes reverts waiting_review to draft" do
    result = described_class.call(
      ticket: ticket,
      decision: :request_changes,
      reason_code: "insufficient_evidence",
      audit_role: "audit_board"
    )

    expect(result.decision).to be_decision_request_changes
    expect(result.ticket).to be_status_draft
  end

  it "rejects an approval with an invalid reason_code" do
    expect do
      described_class.call(
        ticket: ticket,
        decision: :approve,
        reason_code: "security_risk",
        audit_role: "audit_board"
      )
    end.to raise_error(ActiveRecord::RecordInvalid)
  end
end
