require "rails_helper"

RSpec.describe Linestamp::BrandSourcesSyncer do
  let(:syncer) { described_class.new }

  describe "#sync_all" do
    it "syncs brands from brand_sources directory" do
      syncer.sync_all

      brand = Linestamp::Brand.find_by(slug: "nemuinu")
      expect(brand).not_to be_nil
      expect(brand.character_name).to eq("ねむ犬")
      expect(brand.packs.count).to eq(1)
      expect(brand.packs.first.stamps.count).to eq(8)
    end
  end

  describe "#sync_brand" do
    it "syncs a single brand from meta.yml" do
      meta_path = Rails.root.join("brand_sources", "nemuinu", "meta.yml").to_s
      brand = syncer.sync_brand(meta_path)

      expect(brand.slug).to eq("nemuinu")
      expect(brand.character_name).to eq("ねむ犬")
      expect(brand.series_name).to eq("在宅ワークのゆる犬")
      expect(brand.tone_axes["gentle"]).to eq(0.95)
      expect(brand.character_parts["eyes"]).to include("半目")
    end

    it "syncs structured pack fields" do
      meta_path = Rails.root.join("brand_sources", "nemuinu", "meta.yml").to_s
      brand = syncer.sync_brand(meta_path)
      pack = brand.packs.first

      expect(pack.series_theme).to eq("在宅ワーク基本")
      expect(pack.slug).to eq("pack_001")
      expect(pack.layer).to eq("core_work")
      expect(pack.usage_scenes).to include("朝の起動")
      expect(pack.target_emotions).to include("気まずさ")
    end

    it "syncs structured stamp fields" do
      meta_path = Rails.root.join("brand_sources", "nemuinu", "meta.yml").to_s
      brand = syncer.sync_brand(meta_path)
      stamp = brand.packs.first.stamps.find_by(position: 1)

      expect(stamp.label).to eq("いま仕事中だよ")
      expect(stamp.intent).to eq("返信遅延の申し訳なさ通知")
      expect(stamp.situation).to eq("PC前で作業。半目・無表情")
      expect(stamp.search_keywords).to include("仕事中")
    end
  end
end
