module Linestamp
  class ChromaKeyProcessor
    # Green screen color tolerance
    DEFAULT_FUZZ = "20%"

    def initialize(fuzz: DEFAULT_FUZZ)
      @fuzz = fuzz
    end

    # Process a green-background image to transparent PNG meeting LINE spec
    # Returns a Tempfile with the processed image
    # @param input_path [String] path to input image
    # @param spec [Linestamp::ImageSpec, nil] optional image spec (defaults to line_main_370x320)
    def process(input_path, spec: nil)
      spec ||= Linestamp::ImageSpec.find_by(slug: "line_main_370x320")
      max_width = spec&.width || 370
      max_height = spec&.height || 320

      output = Tempfile.new(["linestamp_processed_", ".png"])

      image = MiniMagick::Image.open(input_path)

      # Remove green background (chroma key)
      image.combine_options do |c|
        c.fuzz @fuzz
        c.transparent "#3CB371"
      end

      # Also remove pure green
      image.combine_options do |c|
        c.fuzz "15%"
        c.transparent "#00FF00"
      end

      # Resize to fit LINE spec while preserving aspect ratio
      image.resize "#{max_width}x#{max_height}>"

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
    def resize_for_line(input_path, spec: nil)
      spec ||= Linestamp::ImageSpec.find_by(slug: "line_main_370x320")
      max_width = spec&.width || 370
      max_height = spec&.height || 320

      output = Tempfile.new(["linestamp_resized_", ".png"])

      image = MiniMagick::Image.open(input_path)
      image.resize "#{max_width}x#{max_height}>"
      image.format "png"
      image.write(output.path)

      output
    end
  end
end
