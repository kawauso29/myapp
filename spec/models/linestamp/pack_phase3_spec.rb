# frozen_string_literal: true

require "rails_helper"

RSpec.describe Linestamp::Pack, type: :model do
  let!(:brand) { Linestamp::Brand.create!(slug: "test_brand", character_name: "Test", series_name: "Test Series") }

  describe "purchase_unit_size validation" do
    it "allows 8, 24, 40" do
      [8, 24, 40].each do |size|
        pack = brand.packs.build(series_theme: "Theme", position: size, purchase_unit_size: size)
        expect(pack).to be_valid
      end
    end

    it "rejects other values" do
      pack = brand.packs.build(series_theme: "Theme", position: 1, purchase_unit_size: 16)
      expect(pack).not_to be_valid
      expect(pack.errors[:purchase_unit_size]).to be_present
    end
  end

  describe "sales_count validation" do
    it "rejects negative values" do
      pack = brand.packs.build(series_theme: "Theme", position: 1, sales_count: -1)
      expect(pack).not_to be_valid
    end
  end

  describe "scopes" do
    let!(:published_pack) do
      brand.packs.create!(series_theme: "Published", position: 1, published_at: 1.day.ago, sales_count: 100)
    end
    let!(:unpublished_pack) do
      brand.packs.create!(series_theme: "Unpublished", position: 2, sales_count: 0)
    end

    describe ".published" do
      it "only includes packs with published_at set" do
        expect(Linestamp::Pack.published).to include(published_pack)
        expect(Linestamp::Pack.published).not_to include(unpublished_pack)
      end
    end

    describe ".unpublished" do
      it "only includes packs without published_at" do
        expect(Linestamp::Pack.unpublished).to include(unpublished_pack)
        expect(Linestamp::Pack.unpublished).not_to include(published_pack)
      end
    end

    describe ".best_sellers" do
      let!(:top_seller) do
        brand.packs.create!(series_theme: "Top", position: 3, published_at: 2.days.ago, sales_count: 500)
      end

      it "returns published packs sorted by sales_count desc" do
        results = Linestamp::Pack.best_sellers(10)
        expect(results.first).to eq(top_seller)
        expect(results).not_to include(unpublished_pack)
      end
    end
  end
end
