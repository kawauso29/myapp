require "rails_helper"

RSpec.describe Feedback::Intake do
  describe ".submit" do
    it "creates a new_feedback record when no categorization is given" do
      result = described_class.submit(source: :in_app, raw_text: "Thanks for the app!")

      expect(result.feedback).to be_persisted
      expect(result.feedback).to be_status_new_feedback
      expect(result.escalated_ticket).to be_nil
    end

    it "creates a categorized record when categorization is provided" do
      result = described_class.submit(
        source: :slack,
        raw_text: "minor bug",
        categorization: { "sentiment" => "neutral", "severity" => "low" }
      )

      expect(result.feedback).to be_status_categorized
      expect(result.escalated_ticket).to be_nil
    end

    it "escalates high severity negative feedback to an investigation ticket" do
      result = described_class.submit(
        source: :email,
        raw_text: "service is down and I cannot log in",
        categorization: { "sentiment" => "negative", "severity" => "high" }
      )

      expect(result.feedback).to be_status_escalated
      expect(result.escalated_ticket).to be_present
      expect(result.escalated_ticket).to be_ticket_type_investigation
      expect(result.escalated_ticket).to be_operating_lane_immediate
      expect(result.feedback.reload.linked_ticket_id).to eq(result.escalated_ticket.id)
    end
  end
end
