# frozen_string_literal: true

require "rails_helper"

RSpec.describe Linestamp::CommunicationTheme, type: :model do
  describe "validations" do
    subject { described_class.new(slug: "test_theme", name: "テスト") }

    it { is_expected.to validate_presence_of(:slug) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:slug) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:parent).optional }
    it { is_expected.to have_many(:brand_communication_themes).dependent(:destroy) }
    it { is_expected.to have_many(:brands).through(:brand_communication_themes) }
    it { is_expected.to have_many(:pack_communication_themes).dependent(:destroy) }
    it { is_expected.to have_many(:stamp_communication_themes).dependent(:destroy) }
    it { is_expected.to have_many(:research_communication_themes).dependent(:destroy) }
  end

  describe "slug format" do
    it "rejects invalid slugs" do
      theme = described_class.new(slug: "Invalid Slug!", name: "test")
      expect(theme).not_to be_valid
      expect(theme.errors[:slug]).to be_present
    end

    it "accepts valid slugs" do
      theme = described_class.new(slug: "valid_slug_123", name: "test")
      expect(theme).to be_valid
    end
  end
end
