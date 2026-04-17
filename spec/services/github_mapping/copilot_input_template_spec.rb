require "rails_helper"

RSpec.describe GithubMapping::CopilotInputTemplate do
  describe ".generate" do
    it "returns structured template with all §30.4 fields" do
      ticket = create(:ticket_ledger, service_id: "ai_sns", risk_level: :high)
      result = described_class.generate(ticket)

      expect(result[:template_version]).to eq("1.0")
      expect(result[:template_id]).to start_with("tmpl-operations-")
      expect(result[:context][:service_id]).to eq("ai_sns")
      expect(result[:context][:risk_level]).to eq("high")
      expect(result[:constraints]).to include("§30.6 ルール3: high リスク変更は Copilot 単独で完結させない")
      expect(result[:constraints]).to include("監査部レビュー必須")
    end

    it "medium risk includes reviewer requirement" do
      ticket = create(:ticket_ledger, risk_level: :medium)
      result = described_class.generate(ticket)

      expect(result[:constraints]).to include("レビュワー1名以上の approve 必須")
    end

    it "low risk does not include audit constraints" do
      ticket = create(:ticket_ledger, risk_level: :low)
      result = described_class.generate(ticket)

      expect(result[:constraints]).not_to include("監査部レビュー必須")
    end
  end

  describe "#to_markdown" do
    it "renders Markdown with all context fields" do
      ticket = create(:ticket_ledger, service_id: "ai_sns")
      md = described_class.new(ticket).to_markdown

      expect(md).to include("## Copilot Input Template")
      expect(md).to include("ai_sns")
      expect(md).to include("template_id")
    end
  end

  describe "Phase 35 補強9: template_id persistence" do
    it "persists template_id on the ticket when generate is called" do
      ticket = create(:ticket_ledger, service_id: "ai_sns", ticket_type: :operations)
      expect(ticket.template_id).to be_nil

      described_class.generate(ticket)

      expect(ticket.reload.template_id).to eq("tmpl-operations-#{ticket.id}")
    end

    it "does not overwrite an existing template_id" do
      ticket = create(:ticket_ledger, service_id: "ai_sns", ticket_type: :operations)
      ticket.update!(template_id: "tmpl-operations-#{ticket.id}")

      described_class.generate(ticket)

      expect(ticket.reload.template_id).to eq("tmpl-operations-#{ticket.id}")
    end
  end
end
