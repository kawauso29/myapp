require "rails_helper"

RSpec.describe Linestamp::BrandSourcesSyncer do
  let(:syncer) { described_class.new }

  before do
    # Seed master data needed for sync
    require Rails.root.join("db/seeds/linestamp/masters")
    Linestamp::Seeds.call
  end

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

    it "syncs persona_name from meta.yml" do
      meta_path = Rails.root.join("brand_sources", "nemuinu", "meta.yml").to_s
      brand = syncer.sync_brand(meta_path)
      expect(brand.persona_name).to eq("在宅ワーカー田中さん")
    end

    it "syncs communication themes from meta.yml" do
      meta_path = Rails.root.join("brand_sources", "nemuinu", "meta.yml").to_s
      brand = syncer.sync_brand(meta_path)
      theme_slugs = brand.communication_themes.pluck(:slug)
      expect(theme_slugs).to include("remote_work_report", "appreciation_for_effort", "apology")
    end

    it "syncs attribute values from meta.yml" do
      meta_path = Rails.root.join("brand_sources", "nemuinu", "meta.yml").to_s
      brand = syncer.sync_brand(meta_path)
      value_slugs = brand.attribute_values.pluck(:slug)
      expect(value_slugs).to include("gentle", "animal", "age_20s", "age_30s", "business_user", "remote_work")
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

    it "syncs pack purchase_unit_size" do
      meta_path = Rails.root.join("brand_sources", "nemuinu", "meta.yml").to_s
      brand = syncer.sync_brand(meta_path)
      expect(brand.packs.first.purchase_unit_size).to eq(8)
    end

    it "syncs pack communication themes from manifest" do
      meta_path = Rails.root.join("brand_sources", "nemuinu", "meta.yml").to_s
      brand = syncer.sync_brand(meta_path)
      pack_themes = brand.packs.first.communication_themes.pluck(:slug)
      expect(pack_themes).to include("remote_work_report", "appreciation_for_effort")
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

    it "syncs stamp primary_communication_theme" do
      meta_path = Rails.root.join("brand_sources", "nemuinu", "meta.yml").to_s
      brand = syncer.sync_brand(meta_path)
      pack = brand.packs.first
      pack.stamps.order(:position).each do |stamp|
        expect(stamp.primary_communication_theme_id).to be_present,
          "Stamp ##{stamp.position} '#{stamp.label}' missing primary_communication_theme_id"
      end
      expect(pack.stamps.find_by(position: 1).primary_communication_theme.slug).to eq("remote_work_report")
    end

    it "does NOT touch published_at or sales_count" do
      meta_path = Rails.root.join("brand_sources", "nemuinu", "meta.yml").to_s
      brand = syncer.sync_brand(meta_path)
      pack = brand.packs.first
      pack.update_columns(published_at: "2026-01-01", sales_count: 999)

      # Re-sync
      syncer.sync_brand(meta_path)
      pack.reload
      expect(pack.published_at).to be_present
      expect(pack.sales_count).to eq(999)
    end

    it "warns on unknown theme slug and does not auto-create" do
      meta_path = Rails.root.join("brand_sources/nemuinu/meta.yml")
      original = File.read(meta_path)
      modified = original.gsub("- remote_work_report", "- remote_work_report\n  - nonexistent_slug")
      File.write(meta_path, modified)

      expect(Rails.logger).to receive(:warn).with(/Unknown communication_theme slug: nonexistent_slug/).at_least(:once)
      syncer.sync_brand(meta_path.to_s)

      expect(Linestamp::CommunicationTheme.find_by(slug: "nonexistent_slug")).to be_nil
    ensure
      File.write(meta_path, original)
    end
  end
end
