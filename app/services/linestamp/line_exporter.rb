module Linestamp
  class LineExporter
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

        # main.png (240x240 representative image)
        if @pack.main_image.attached?
          zos.put_next_entry("main.png")
          @pack.main_image.open do |file|
            zos.write(file.read)
          end
        end

        # tab.png (96x74 tab image)
        if @pack.tab_image.attached?
          zos.put_next_entry("tab.png")
          @pack.tab_image.open do |file|
            zos.write(file.read)
          end
        end
      end

      zip_file
    end
  end
end
