require "rails_helper"

RSpec.describe Linestamp::BrandSourcesSyncer do
  let(:syncer) { described_class.new }

  describe "#sync_all" do
    it "syncs brands from brand_sources directory" do
      syncer.sync_all

      brand = Linestamp::Brand.find_by(slug: "nemuinu")
      expect(brand).not_to be_nil
      expect(brand.name).to eq("ねむ犬")
      expect(brand.packs.count).to eq(1)
      expect(brand.packs.first.stamps.count).to eq(8)
    end
  end

  describe "#sync_brand" do
    it "syncs a single brand from meta.yml" do
      meta_path = Rails.root.join("brand_sources", "nemuinu", "meta.yml").to_s
      brand = syncer.sync_brand(meta_path)

      expect(brand.slug).to eq("nemuinu")
      expect(brand.name).to eq("ねむ犬")
    end
  end
end
