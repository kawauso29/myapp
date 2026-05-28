require "rails_helper"

RSpec.describe SlackNotifierService do
  describe ".notify" do
    let(:notifier) { instance_double(described_class, send_message: true) }

    before do
      allow(described_class).to receive(:new).and_return(notifier)
      allow(Rails.logger).to receive(:warn)
      allow(Rails.logger).to receive(:error)
    end

    it "jobs channel の webhook を使う" do
      stub_const("#{described_class}::WEBHOOK_URLS", { error: "https://example.com/error-hook", jobs: "https://example.com/jobs-hook" })

      described_class.notify(text: "hello", channel: :jobs)

      expect(described_class).to have_received(:new).with("https://example.com/jobs-hook")
    end

    it "error channel は error webhook を使う" do
      stub_const("#{described_class}::WEBHOOK_URLS", { error: "https://example.com/error-hook", jobs: "https://example.com/jobs-hook" })

      described_class.notify(text: "hello", channel: :error)

      expect(described_class).to have_received(:new).with("https://example.com/error-hook")
    end

    it "jobs webhook が無いときは warn を出して送信しない" do
      stub_const("#{described_class}::WEBHOOK_URLS", { error: "https://example.com/error-hook", jobs: nil })

      described_class.notify(text: "hello", channel: :jobs)

      expect(described_class).not_to have_received(:new)
      expect(Rails.logger).to have_received(:warn)
    end
  end
end
