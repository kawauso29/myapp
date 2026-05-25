require "rails_helper"

RSpec.describe Linestamp::Brand, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:slug) }
    it { is_expected.to validate_presence_of(:name) }

    it "validates uniqueness of slug" do
      described_class.create!(slug: "test", name: "Test")
      brand = described_class.new(slug: "test", name: "Test2")
      expect(brand).not_to be_valid
    end
  end

  describe "associations" do
    it { is_expected.to have_many(:packs) }
  end

  describe "AASM states" do
    let(:brand) { described_class.create!(slug: "test-brand", name: "Test Brand") }

    it "starts as planned" do
      expect(brand).to be_planned
    end

    it "transitions planned -> prompt_ready when prompt is set" do
      brand.update!(brand_prompt: "test prompt")
      brand.mark_prompt_ready!
      expect(brand).to be_prompt_ready
    end

    it "cannot transition to prompt_ready without prompt" do
      expect(brand.may_mark_prompt_ready?).to be false
    end
  end
end
