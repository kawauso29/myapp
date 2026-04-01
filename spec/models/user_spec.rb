require "rails_helper"

RSpec.describe User, type: :model do
  describe "validations" do
    it "is valid with default factory attributes" do
      user = build(:user)
      expect(user).to be_valid
    end

    it "requires username" do
      user = build(:user, username: nil)
      expect(user).not_to be_valid
      expect(user.errors[:username]).to include("can't be blank")
    end

    it "requires unique username" do
      create(:user, username: "taken")
      user = build(:user, username: "taken")
      expect(user).not_to be_valid
      expect(user.errors[:username]).to include("has already been taken")
    end

    it "rejects username longer than 30 characters" do
      user = build(:user, username: "a" * 31)
      expect(user).not_to be_valid
    end

    it "requires email (from Devise)" do
      user = build(:user, email: nil)
      expect(user).not_to be_valid
    end

    it "requires password (from Devise)" do
      user = build(:user, password: nil)
      expect(user).not_to be_valid
    end

    it "validates owner_score is non-negative" do
      user = build(:user, owner_score: -1)
      expect(user).not_to be_valid
      expect(user.errors[:owner_score]).to be_present
    end
  end

  describe "plan enum" do
    it "defaults to free" do
      user = build_stubbed(:user)
      expect(user).to be_free
    end

    it "supports free, light, premium plans" do
      expect(User.plans.keys).to contain_exactly("free", "light", "premium")
    end

    it "maps free=0, light=1, premium=2" do
      expect(User.plans).to eq("free" => 0, "light" => 1, "premium" => 2)
    end
  end

  describe "associations" do
    it { is_expected.to have_many(:ai_users).dependent(:nullify) }
    it { is_expected.to have_many(:user_ai_likes).dependent(:destroy) }
    it { is_expected.to have_many(:user_favorite_ais).dependent(:destroy) }
    it { is_expected.to have_many(:favorite_ai_users).through(:user_favorite_ais) }
    it { is_expected.to have_many(:post_reports).dependent(:destroy) }
  end
end
