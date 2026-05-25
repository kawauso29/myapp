module Linestamp
  class DailyOrchestratorJob < ApplicationJob
    queue_as :linestamp_default

    def perform
      # Step 1: Sync brand sources from filesystem
      SyncBrandSourcesJob.perform_later

      # Step 2: Compose prompts for brands in planned state
      Linestamp::Brand.where(status: "planned").find_each do |brand|
        ComposeBrandPromptJob.perform_later(brand.id)
      end

      # Step 3: Compose pack sheet prompts for packs in planned state
      Linestamp::Pack.where(status: "planned").find_each do |pack|
        ComposePackSheetPromptJob.perform_later(pack.id)
      end

      # Step 4: Compose stamp prompts for stamps in planned state
      Linestamp::Stamp.where(status: "planned").find_each do |stamp|
        ComposeStampPromptsJob.perform_later(stamp.id)
      end

      # Step 5: Notify daily summary
      notify_summary
    end

    private

    def notify_summary
      stats = {
        brands: Linestamp::Brand.count,
        packs: Linestamp::Pack.count,
        stamps_total: Linestamp::Stamp.count,
        stamps_processed: Linestamp::Stamp.where(status: "processed").count
      }

      Linestamp::SlackNotifier.notify(
        text: ":art: *Linestamp Daily Summary*\n" \
              "Brands: #{stats[:brands]} | Packs: #{stats[:packs]} | " \
              "Stamps: #{stats[:stamps_processed]}/#{stats[:stamps_total]} processed"
      )
    end
  end
end
