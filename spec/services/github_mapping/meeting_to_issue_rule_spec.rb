require "rails_helper"

RSpec.describe GithubMapping::MeetingToIssueRule do
  let(:definition) { create(:meeting_definition, meeting_key: "weekly_dept") }
  let(:meeting) do
    create(:meeting_ledger,
           meeting_definition: definition,
           meeting_key: "weekly_dept",
           hold_items: [{ "title" => "Missing KPI", "reason" => "missing_kpi_definition" }],
           escalations: [{ "ticket_id" => 42, "escalation_to" => "monthly", "reason" => "audit_block" }],
           directives: [{ "improvements" => { "detected" => 1, "details" => [{ "title" => "High overdue", "rule" => "high_overdue_rate", "ticket_id" => 99 }] } }])
  end

  describe ".apply" do
    it "generates issues from hold_items" do
      results = described_class.apply(meeting)
      hold_issues = results.select { |r| r[:title].start_with?("[hold]") }

      expect(hold_issues.size).to eq(1)
      expect(hold_issues.first[:title]).to include("Missing KPI")
      expect(hold_issues.first[:labels]).to include("meeting:hold")
    end

    it "generates issues from escalations" do
      results = described_class.apply(meeting)
      esc_issues = results.select { |r| r[:title].start_with?("[escalation]") }

      expect(esc_issues.size).to eq(1)
      expect(esc_issues.first[:title]).to include("ticket #42")
    end

    it "generates issues from improvements" do
      results = described_class.apply(meeting)
      imp_issues = results.select { |r| r[:title].start_with?("[improvement]") }

      expect(imp_issues.size).to eq(1)
      expect(imp_issues.first[:title]).to include("High overdue")
    end

    it "returns empty for meeting with no actionable items" do
      clean_meeting = create(:meeting_ledger,
                             meeting_definition: definition,
                             meeting_key: "weekly_dept",
                             hold_items: [],
                             escalations: [],
                             directives: [])
      results = described_class.apply(clean_meeting)
      expect(results).to be_empty
    end
  end
end
