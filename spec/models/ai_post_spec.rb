require "rails_helper"

RSpec.describe AiPost, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:ai_user) }
    it { is_expected.to belong_to(:reply_to_post).class_name("AiPost").optional }
    it { is_expected.to have_many(:replies) }
    it { is_expected.to have_many(:ai_post_likes).dependent(:destroy) }
    it { is_expected.to have_many(:user_ai_likes).dependent(:destroy) }
    it { is_expected.to have_many(:post_interest_tags).dependent(:destroy) }
    it { is_expected.to have_many(:interest_tags).through(:post_interest_tags) }
    it { is_expected.to have_many(:post_reports).dependent(:destroy) }
  end

  describe "validations" do
    it "is valid with default factory attributes" do
      post = build(:ai_post)
      expect(post).to be_valid
    end

    it "requires content" do
      post = build(:ai_post, content: nil)
      expect(post).not_to be_valid
      expect(post.errors[:content]).to include("can't be blank")
    end

    it "rejects content longer than 500 characters" do
      post = build(:ai_post, content: "a" * 501)
      expect(post).not_to be_valid
      expect(post.errors[:content]).to be_present
    end

    it "accepts content of exactly 500 characters" do
      post = build(:ai_post, content: "a" * 500)
      expect(post).to be_valid
    end
  end

  describe "enums" do
    it "defines mood_expressed with positive, neutral, negative" do
      post = build_stubbed(:ai_post, mood_expressed: :positive)
      expect(post).to be_mood_expressed_positive
    end

    it "defines motivation_type enum" do
      post = build_stubbed(:ai_post, motivation_type: :venting)
      expect(post).to be_motivation_type_venting
    end
  end

  describe "scopes" do
    describe ".visible" do
      it "returns only visible posts" do
        visible_post = create(:ai_post, is_visible: true)
        create(:ai_post, :hidden)

        expect(AiPost.visible).to eq([visible_post])
      end
    end

    describe ".timeline" do
      it "returns visible posts in descending creation order" do
        old_post = create(:ai_post, created_at: 2.hours.ago)
        new_post = create(:ai_post, created_at: 1.hour.ago)
        create(:ai_post, :hidden)

        expect(AiPost.timeline).to eq([new_post, old_post])
      end
    end
  end

  describe "#is_reply?" do
    it "returns true when reply_to_post_id is present" do
      parent = create(:ai_post)
      reply = build_stubbed(:ai_post, reply_to_post_id: parent.id)

      expect(reply.is_reply?).to be true
    end

    it "returns false when reply_to_post_id is nil" do
      post = build_stubbed(:ai_post, reply_to_post_id: nil)

      expect(post.is_reply?).to be false
    end
  end
end
