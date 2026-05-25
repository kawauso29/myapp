module Linestamp
  class LineExporter
    # LINE Creator Studio requirements:
    # - main: 240x240 PNG (tab image)
    # - stamps: 370x320 max, transparent PNG
    # - ZIP file with specific structure

    MAIN_IMAGE_SIZE = "240x240"
    TAB_IMAGE_SIZE = "96x74"

    def initialize(pack)
      @pack = pack
    end

    # Generate a ZIP file for LINE submission
    # Returns a Tempfile containing the ZIP
    def export
      stamps = @pack.stamps.where(status: "processed").order(:position)
      raise "Pack has no processed stamps" if stamps.empty?

      zip_file = Tempfile.new(["linestamp_export_#{@pack.id}_", ".zip"])

      Zip::OutputStream.open(zip_file.path) do |zos|
        stamps.each_with_index do |stamp, idx|
          next unless stamp.processed_image.attached?

          filename = format("%02d.png", idx + 1)
          zos.put_next_entry(filename)

          stamp.processed_image.open do |file|
            zos.write(file.read)
          end
        end

        # Add tab image if sheet_image exists
        if @pack.sheet_image.attached?
          zos.put_next_entry("tab.png")
          @pack.sheet_image.open do |file|
            tab_image = MiniMagick::Image.open(file.path)
            tab_image.resize TAB_IMAGE_SIZE
            tab_image.format "png"
            temp = Tempfile.new(["tab_", ".png"])
            tab_image.write(temp.path)
            zos.write(File.read(temp.path))
            temp.close!
          end
        end
      end

      zip_file
    end
  end
end
