require "rails_helper"

RSpec.describe Feedback::Intake, "case-insensitive severity classification" do
  it "treats 'Negative'/'HIGH' as high severity" do
    result = described_class.submit(
      source: :in_app,
      raw_text: "It crashed",
      categorization: { "sentiment" => "Negative", "severity" => "HIGH" }
    )

    expect(result.feedback).to be_status_escalated
    expect(result.escalated_ticket).to be_present
  end

  it "still escalates lowercased values" do
    result = described_class.submit(
      source: :in_app,
      raw_text: "It crashed",
      categorization: { "sentiment" => "negative", "severity" => "high" }
    )

    expect(result.feedback).to be_status_escalated
  end

  it "does not escalate when sentiment is positive" do
    result = described_class.submit(
      source: :in_app,
      raw_text: "great",
      categorization: { "sentiment" => "positive", "severity" => "high" }
    )

    expect(result.feedback).not_to be_status_escalated
    expect(result.escalated_ticket).to be_nil
  end
end
