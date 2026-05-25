# frozen_string_literal: true

require "rails_helper"

RSpec.describe Linestamp::Search::FacetedSearcher, type: :service do
  let!(:tone_axis) { Linestamp::AttributeAxis.create!(slug: "tone", name: "トーン", kind: "tone") }
  let!(:motif_axis) { Linestamp::AttributeAxis.create!(slug: "motif", name: "モチーフ", kind: "motif") }
  let!(:setting_axis) { Linestamp::AttributeAxis.create!(slug: "setting", name: "シーン", kind: "setting") }

  let!(:gentle) { Linestamp::AttributeValue.create!(axis: tone_axis, slug: "gentle", name: "ゆるい") }
  let!(:neat) { Linestamp::AttributeValue.create!(axis: tone_axis, slug: "neat", name: "きっちり") }
  let!(:animal) { Linestamp::AttributeValue.create!(axis: motif_axis, slug: "animal", name: "動物") }
  let!(:remote) { Linestamp::AttributeValue.create!(axis: setting_axis, slug: "remote_work", name: "在宅") }

  let!(:theme_rw) { Linestamp::CommunicationTheme.create!(slug: "remote_work_report", name: "在宅ワーク報告") }
  let!(:theme_gr) { Linestamp::CommunicationTheme.create!(slug: "gratitude", name: "感謝") }

  let!(:brand) { Linestamp::Brand.create!(slug: "search_brand", character_name: "Test", series_name: "Test") }
  let!(:pack) { brand.packs.create!(series_theme: "Pack1", position: 1, published_at: 1.day.ago, sales_count: 50) }
  let!(:pack2) { brand.packs.create!(series_theme: "Pack2", position: 2, published_at: 2.days.ago, sales_count: 100) }

  before do
    # Brand has gentle + animal + remote_work_report
    brand.brand_attribute_values.create!(attribute_value: gentle)
    brand.brand_attribute_values.create!(attribute_value: animal)
    brand.brand_communication_themes.create!(communication_theme: theme_rw)

    # Pack1 has gentle + remote_work_report
    pack.pack_attribute_values.create!(attribute_value: gentle)
    pack.pack_attribute_values.create!(attribute_value: remote)
    pack.pack_communication_themes.create!(communication_theme: theme_rw)

    # Pack2 has neat + gratitude (no overlap with Pack1 filters)
    pack2.pack_attribute_values.create!(attribute_value: neat)
    pack2.pack_communication_themes.create!(communication_theme: theme_gr)
  end

  describe "#call" do
    it "filters packs by theme" do
      result = described_class.new(theme: ["remote_work_report"], target: "pack").call
      expect(result.records).to include(pack)
      expect(result.records).not_to include(pack2)
    end

    it "filters packs by attribute (tone)" do
      result = described_class.new(tone: ["gentle"], target: "pack").call
      expect(result.records).to include(pack)
      expect(result.records).not_to include(pack2)
    end

    it "cross-filters theme + tone + setting" do
      result = described_class.new(
        theme: ["remote_work_report"], tone: ["gentle"], setting: ["remote_work"], target: "pack"
      ).call
      expect(result.records).to eq([pack])
      expect(result.total_count).to eq(1)
    end

    it "filters brands by theme" do
      result = described_class.new(theme: ["remote_work_report"], target: "brand").call
      expect(result.records).to include(brand)
    end

    it "returns facets with counts" do
      result = described_class.new(theme: ["remote_work_report"], target: "pack").call
      tone_facets = result.facets["tone"]
      expect(tone_facets).to be_an(Array)
      gentle_facet = tone_facets.find { |f| f[:slug] == "gentle" }
      expect(gentle_facet[:count]).to eq(1)
    end

    it "returns theme facets" do
      result = described_class.new(tone: ["gentle"], target: "pack").call
      theme_facets = result.facets["communication_theme"]
      rw_facet = theme_facets.find { |f| f[:slug] == "remote_work_report" }
      expect(rw_facet[:count]).to eq(1)
    end

    it "respects limit" do
      result = described_class.new(target: "pack", limit: 1).call
      expect(result.records.size).to eq(1)
    end

    it "raises on invalid target" do
      expect {
        described_class.new(target: "invalid").call
      }.to raise_error(ArgumentError)
    end
  end
end
