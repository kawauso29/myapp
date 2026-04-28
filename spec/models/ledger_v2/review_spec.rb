require "rails_helper"

RSpec.describe LedgerV2::Review, type: :model do
  let(:ticket) do
    LedgerV2::Ticket.create!(canonical_key: "ledger_v2:test:max:weekly:2026w18", title: "テスト")
  end

  def valid_attrs(overrides = {})
    {
      reviewable: ticket,
      decision:   "accepted"
    }.merge(overrides)
  end

  describe "create（基本保存）" do
    it "必須カラムが揃っていれば保存できる" do
      review = described_class.new(valid_attrs)
      expect(review.save).to be true
    end

    it "reviewed_at がデフォルトで現在時刻になる" do
      freeze_time = Time.current
      allow(Time).to receive(:current).and_return(freeze_time)
      review = described_class.create!(valid_attrs)
      expect(review.reviewed_at).to be_within(1.second).of(freeze_time)
    end

    it "明示した reviewed_at は維持される" do
      t = 2.days.ago
      review = described_class.create!(valid_attrs(reviewed_at: t))
      expect(review.reviewed_at).to be_within(1.second).of(t)
    end
  end

  describe "validations" do
    it "decision が必須" do
      review = described_class.new(valid_attrs(decision: nil))
      expect(review).not_to be_valid
      expect(review.errors[:decision]).to be_present
    end

    it "decision は DECISIONS の値のみ受け付ける" do
      review = described_class.new(valid_attrs(decision: "approved"))
      expect(review).not_to be_valid
      expect(review.errors[:decision]).to be_present
    end

    it "reviewable が必須" do
      review = described_class.new(decision: "accepted", reviewable: nil)
      expect(review).not_to be_valid
    end
  end

  describe "polymorphic reviewable" do
    it "Ticket を reviewable にできる" do
      review = described_class.create!(valid_attrs)
      expect(review.reviewable).to eq(ticket)
      expect(review.reviewable_type).to eq("LedgerV2::Ticket")
    end

    it "Artifact を reviewable にできる" do
      artifact = LedgerV2::Artifact.create!(artifact_type: "weekly_review", title: "W18", format: "markdown")
      review = described_class.create!(valid_attrs(reviewable: artifact))
      expect(review.reviewable).to eq(artifact)
      expect(review.reviewable_type).to eq("LedgerV2::Artifact")
    end
  end
end
