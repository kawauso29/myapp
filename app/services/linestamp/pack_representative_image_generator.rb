module Linestamp
  class PackRepresentativeImageGenerator
    KIND_TO_SPEC = {
      main: "line_main_240x240",
      tab: "line_tab_96x74"
    }.freeze

    # @param pack [Linestamp::Pack]
    # @param kind [:main, :tab]
    # @param source_stamp [Linestamp::Stamp] 元画像にする stamp(processed_image 必須)
    def call(pack:, kind:, source_stamp:)
      spec = Linestamp::ImageSpec.find_by!(slug: KIND_TO_SPEC.fetch(kind))
      raise ArgumentError, "source_stamp.processed_image not attached" unless source_stamp.processed_image.attached?

      raw = save_attachment_to_tempfile(source_stamp.processed_image)
      out = resize_to_spec(raw.path, spec)

      target = (kind == :main) ? :main_image : :tab_image
      pack.public_send(target).attach(io: out, filename: "#{kind}.png", content_type: "image/png")

      # Record source stamp
      column = (kind == :main) ? :main_source_stamp_id : :tab_source_stamp_id
      pack.update_column(column, source_stamp.id)
    ensure
      raw&.close
      raw&.unlink
    end

    private

    def resize_to_spec(input_path, spec)
      output = Tempfile.new(["resize_out", ".png"], binmode: true)
      output.close

      content_w = spec.content_width
      content_h = spec.content_height

      MiniMagick::Tool::Convert.new do |c|
        c << input_path
        c.background "none"
        c.resize "#{content_w}x#{content_h}>"
        c.gravity "center"
        c.extent "#{spec.width}x#{spec.height}"
        c << output.path
      end

      result = Tempfile.new(["resize_result", ".png"], binmode: true)
      result.write(File.binread(output.path))
      result.rewind
      result
    ensure
      output&.unlink if output && File.exist?(output.path)
    end

    def save_attachment_to_tempfile(attachment)
      f = Tempfile.new(["attached", ".png"], binmode: true)
      attachment.download { |chunk| f.write(chunk) }
      f.rewind
      f
    end
  end
end
