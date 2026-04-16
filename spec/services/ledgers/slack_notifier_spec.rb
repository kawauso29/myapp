require "rails_helper"

RSpec.describe Ledgers::SlackNotifier do
  describe ".notify" do
    let(:payload) do
      {
        operation: "weekly_dept",
        counts: { tickets_created: 2, held_items: 1 },
        overdue_marked: 0
      }
    end

    before do
      allow(ENV).to receive(:[]).and_call_original
    end

    it "posts payload summary to slack webhook" do
      allow(ENV).to receive(:[]).with("SLACK_WEBHOOK_URL_LEDGER").and_return("https://example.com/webhook")
      allow(ENV).to receive(:[]).with("SLACK_WEBHOOK_URL").and_return(nil)

      response = instance_double(Net::HTTPSuccess, code: "200", body: "ok")
      http = instance_double(Net::HTTP)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:open_timeout=)
      allow(http).to receive(:read_timeout=)
      allow(Net::HTTP).to receive(:new).with("example.com", 443).and_return(http)
      allow(http).to receive(:request) do |request|
        body = JSON.parse(request.body)
        expect(body["text"]).to include("operation=weekly_dept")
        expect(body["text"]).to include("tickets_created=2")
        expect(body["text"]).to include("held_items=1")
        expect(body["text"]).to include("overdue_marked=0")
        response
      end

      described_class.notify(payload)
    end

    it "includes improvement details when present" do
      payload_with_improvements = payload.merge(
        improvements: {
          details: [
            { rule: "high_overdue_rate", title: "Improvement: High overdue rate (25.0%)" }
          ]
        }
      )
      allow(ENV).to receive(:[]).with("SLACK_WEBHOOK_URL_LEDGER").and_return("https://example.com/webhook")
      allow(ENV).to receive(:[]).with("SLACK_WEBHOOK_URL").and_return(nil)

      response = instance_double(Net::HTTPSuccess, code: "200", body: "ok")
      http = instance_double(Net::HTTP)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:open_timeout=)
      allow(http).to receive(:read_timeout=)
      allow(Net::HTTP).to receive(:new).with("example.com", 443).and_return(http)
      allow(http).to receive(:request) do |request|
        body = JSON.parse(request.body)
        expect(body["text"]).to include("improvements_created=1")
        expect(body["text"]).to include("improvement_rules=high_overdue_rate")
        response
      end

      described_class.notify(payload_with_improvements)
    end

    it "skips notification when no webhook URL is configured" do
      allow(ENV).to receive(:[]).with("SLACK_WEBHOOK_URL_LEDGER").and_return(nil)
      allow(ENV).to receive(:[]).with("SLACK_WEBHOOK_URL").and_return(nil)
      allow(Rails.logger).to receive(:warn)
      allow(Net::HTTP).to receive(:new)

      described_class.notify(payload)

      expect(Net::HTTP).not_to have_received(:new)
      expect(Rails.logger).to have_received(:warn).with(
        "[Ledgers::SlackNotifier] webhook URL is not configured. skip notification."
      )
    end
  end
end
