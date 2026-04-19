require "rails_helper"

RSpec.describe SlackNotifierService do
  describe ".notify" do
    let(:notifier) { instance_double(described_class, send_message: true) }

    before do
      allow(described_class).to receive(:new).and_return(notifier)
      allow(Rails.logger).to receive(:warn)
      allow(Rails.logger).to receive(:error)
    end

    it "service_id用 webhook がある場合はそれを優先する" do
      create(:service_ledger, service_id: "ai_sns", metadata: { "slack_webhook_url" => "https://example.com/service-hook" })

      described_class.notify(text: "hello", channel: :jobs, service_id: "ai_sns")

      expect(described_class).to have_received(:new).with("https://example.com/service-hook")
    end

    it "service_id用 webhook がない場合は channel webhook にフォールバックする" do
      stub_const("#{described_class}::WEBHOOK_URLS", { error: "https://example.com/error-hook", jobs: "https://example.com/jobs-hook" })
      create(:service_ledger, service_id: "ai_sns", metadata: {})

      described_class.notify(text: "hello", channel: :jobs, service_id: "ai_sns")

      expect(described_class).to have_received(:new).with("https://example.com/jobs-hook")
    end

    it "service_id用 webhook が http の場合は無視してフォールバックする" do
      stub_const("#{described_class}::WEBHOOK_URLS", { error: "https://example.com/error-hook", jobs: "https://example.com/jobs-hook" })
      create(:service_ledger, service_id: "ai_sns", metadata: { "slack_webhook_url" => "http://example.com/service-hook" })

      described_class.notify(text: "hello", channel: :jobs, service_id: "ai_sns")

      expect(described_class).to have_received(:new).with("https://example.com/jobs-hook")
    end
  end
end
