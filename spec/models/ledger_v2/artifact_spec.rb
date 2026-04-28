require "rails_helper"

RSpec.describe LedgerV2::Artifact, type: :model do
  def valid_attrs(overrides = {})
    {
      artifact_type: "weekly_review",
      title:         "Week 18 Review",
      format:        "markdown"
    }.merge(overrides)
  end

  describe "create（基本保存）" do
    it "必須カラムが揃っていれば保存できる" do
      artifact = described_class.new(valid_attrs)
      expect(artifact.save).to be true
    end

    it "デフォルトの review_status は draft になる" do
      artifact = described_class.create!(valid_attrs)
      expect(artifact.review_status_draft?).to be true
    end

    it "デフォルトの format は markdown になる" do
      artifact = described_class.new(valid_attrs.except(:format))
      artifact.save!
      expect(artifact.format).to eq("markdown")
    end
  end

  describe "validations" do
    it "artifact_type が必須" do
      artifact = described_class.new(valid_attrs(artifact_type: nil))
      expect(artifact).not_to be_valid
      expect(artifact.errors[:artifact_type]).to be_present
    end

    it "title が必須" do
      artifact = described_class.new(valid_attrs(title: nil))
      expect(artifact).not_to be_valid
      expect(artifact.errors[:title]).to be_present
    end
  end

  describe "associations" do
    let(:run) { LedgerV2::Run.create!(runner_name: "WeeklyRunner") }
    let(:ticket) do
      LedgerV2::Ticket.create!(canonical_key: "ledger_v2:test:max:weekly:2026w18", title: "テスト")
    end

    it "Run に紐づけられる" do
      artifact = described_class.create!(valid_attrs(run: run))
      expect(artifact.run).to eq(run)
    end

    it "related_ticket に紐づけられる" do
      artifact = described_class.create!(valid_attrs(related_ticket: ticket))
      expect(artifact.related_ticket).to eq(ticket)
    end
  end

  describe "scopes" do
    let!(:draft_one)   { described_class.create!(valid_attrs(review_status: :draft)) }
    let!(:pending_one) { described_class.create!(valid_attrs(review_status: :pending)) }
    let!(:published_one) { described_class.create!(valid_attrs(review_status: :published)) }

    it ".awaiting_review は draft / pending を返す" do
      expect(described_class.awaiting_review).to contain_exactly(draft_one, pending_one)
    end

    it ".published_only は published を返す" do
      expect(described_class.published_only).to contain_exactly(published_one)
    end
  end
end
