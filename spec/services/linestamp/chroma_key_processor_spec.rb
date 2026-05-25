require "rails_helper"

RSpec.describe Linestamp::ChromaKeyProcessor do
  let(:processor) { described_class.new }

  before do
    skip "ImageMagick not installed" unless system("which mogrify > /dev/null 2>&1")
  end

  describe "#process" do
    it "processes a green background image" do
      temp_input = Tempfile.new(["test_green_", ".png"])
      system("convert -size 100x100 xc:'#00FF00' #{temp_input.path}")

      result = processor.process(temp_input.path)
      expect(File.exist?(result.path)).to be true
      expect(File.size(result.path)).to be > 0

      image = MiniMagick::Image.open(result.path)
      expect(image.type).to eq("PNG")

      result.close!
      temp_input.close!
    end
  end

  describe "#resize_for_line" do
    it "resizes image to fit LINE spec" do
      temp_input = Tempfile.new(["test_large_", ".png"])
      system("convert -size 800x800 xc:white #{temp_input.path}")

      result = processor.resize_for_line(temp_input.path)
      image = MiniMagick::Image.open(result.path)
      expect(image.width).to be <= 370
      expect(image.height).to be <= 320

      result.close!
      temp_input.close!
    end
  end
end
