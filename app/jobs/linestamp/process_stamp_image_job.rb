module Linestamp
  class ProcessStampImageJob < ApplicationJob
    queue_as :linestamp_process

    def perform(stamp_id)
      stamp = Linestamp::Stamp.find(stamp_id)
      return unless stamp.raw_uploaded?
      return unless stamp.raw_image.attached?

      stamp.start_processing!

      processor = Linestamp::ChromaKeyProcessor.new
      spec = stamp.pack.effective_image_spec

      stamp.raw_image.open do |raw_file|
        processed_file = if processor.already_transparent?(raw_file.path)
                           processor.resize_for_line(raw_file.path, spec: spec)
        else
                           processor.process(raw_file.path, spec: spec)
        end

        stamp.processed_image.attach(
          io: File.open(processed_file.path),
          filename: "stamp_#{stamp.pack_id}_#{stamp.position}.png",
          content_type: "image/png"
        )

        processed_file.close!
      end

      stamp.mark_processed!

      # Check if all stamps in the pack are processed
      pack = stamp.pack
      if pack.all_stamps_processed? && pack.may_mark_stamps_complete?
        pack.mark_stamps_complete!
        Linestamp::SlackNotifier.notify(
          text: ":white_check_mark: All stamps processed for: #{pack.brand.character_name} / #{pack.series_theme}"
        )
      end
    rescue StandardError => e
      stamp.mark_failed! if stamp.may_mark_failed?
      raise e
    end
  end
end
