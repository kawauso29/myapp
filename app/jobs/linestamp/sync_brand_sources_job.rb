module Linestamp
  class SyncBrandSourcesJob < ApplicationJob
    queue_as :linestamp_default

    def perform
      syncer = Linestamp::BrandSourcesSyncer.new
      syncer.sync_all
    end
  end
end
