require "rails_helper"

RSpec.describe Linestamp::ChromaKeyProcessor do
  let(:processor) { described_class.new }

  describe "#process" do
    before do
      skip "ImageMagick not installed" unless imagemagick_available?
    end

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
    before do
      skip "ImageMagick not installed" unless imagemagick_available?
    end

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

  describe ".ensure_image_magick_cli!" do
    it "raises custom error when both mogrify and magick are unavailable" do
      allow(described_class).to receive(:command_available?).with("mogrify").and_return(false)
      allow(described_class).to receive(:command_available?).with("magick").and_return(false)

      expect { described_class.ensure_image_magick_cli! }
        .to raise_error(Linestamp::ChromaKeyProcessor::MissingImageMagickError)
    end
  end
end
