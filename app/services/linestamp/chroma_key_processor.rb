module Linestamp
  class ChromaKeyProcessor
    # LINE stamp spec: 370x320 max, transparent background, PNG
    LINE_MAX_WIDTH = 370
    LINE_MAX_HEIGHT = 320
    # Green screen color tolerance
    DEFAULT_FUZZ = "20%"

    def initialize(fuzz: DEFAULT_FUZZ)
      @fuzz = fuzz
    end

    # Process a green-background image to transparent PNG meeting LINE spec
    # Returns a Tempfile with the processed image
    def process(input_path)
      output = Tempfile.new(["linestamp_processed_", ".png"])

      image = MiniMagick::Image.open(input_path)

      # Remove green background (chroma key)
      image.combine_options do |c|
        c.fuzz @fuzz
        c.transparent "#00FF00"
      end

      # Resize to fit LINE spec while preserving aspect ratio
      image.resize "#{LINE_MAX_WIDTH}x#{LINE_MAX_HEIGHT}>"

      # Ensure PNG format
      image.format "png"
      image.write(output.path)

      output
    end

    # Check if an image already has transparency (skip chroma key)
    def already_transparent?(input_path)
      image = MiniMagick::Image.open(input_path)
      # Check if alpha channel exists
      image.data["channelDepth"]&.key?("alpha") || image.type == "PNG" && image["%[opaque]"] == "False"
    rescue StandardError
      false
    end

    # Process already-transparent image: just resize to LINE spec
    def resize_for_line(input_path)
      output = Tempfile.new(["linestamp_resized_", ".png"])

      image = MiniMagick::Image.open(input_path)
      image.resize "#{LINE_MAX_WIDTH}x#{LINE_MAX_HEIGHT}>"
      image.format "png"
      image.write(output.path)

      output
    end
  end
end
