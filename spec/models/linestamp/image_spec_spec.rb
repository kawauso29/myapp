require "rails_helper"

RSpec.describe Linestamp::ImageSpec, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:slug) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:width) }
    it { is_expected.to validate_presence_of(:height) }

    it "validates uniqueness of slug" do
      described_class.create!(slug: "test_spec", name: "Test", width: 100, height: 100)
      spec = described_class.new(slug: "test_spec", name: "Test2", width: 200, height: 200)
      expect(spec).not_to be_valid
    end
  end

  describe "associations" do
    it { is_expected.to have_many(:packs) }
  end

  describe "#content_width / #content_height" do
    let(:spec) { described_class.new(width: 370, height: 320, margin_px: 10) }

    it "calculates content dimensions" do
      expect(spec.content_width).to eq(350)
      expect(spec.content_height).to eq(300)
    end
  end

  describe ".default" do
    it "returns the line_main_370x320 spec" do
      spec = described_class.create!(slug: "line_main_370x320", name: "LINE Main", width: 370, height: 320)
      expect(described_class.default).to eq(spec)
    end
  end
end
