# frozen_string_literal: true

require "rails_helper"

RSpec.describe Linestamp::DesignerKit::Stamp do
  let(:brand) do
    Linestamp::Brand.create!(
      slug: "kit_brand",
      character_name: "Kit Brand",
      series_name: "Kit Series"
    )
  end
  let(:pack) do
    brand.packs.create!(
      slug: "kit_pack",
      series_theme: "Kit Pack",
      position: 1,
      purchase_unit_size: 8
    )
  end
  let(:stamp) do
    pack.stamps.create!(
      position: 1,
      label: "了解",
      prompt: "Designer prompt",
      situation: "PC前で確認する",
      intent: "確認済みを伝える",
      usage_scene: "業務チャット",
      skip_primary_theme_guard: true
    )
  end

  def zip_entries(path)
    Zip::File.open(path) { |zip| zip.map(&:name) }
  end

  it "exports prompt, readme, and reference images" do
    brand.base_image.attach(io: StringIO.new("brand image"), filename: "brand_base.png", content_type: "image/png")
    pack.sheet_image.attach(io: StringIO.new("pack image"), filename: "pack_sheet.png", content_type: "image/png")

    zip = described_class.new(stamp).export

    expect(zip_entries(zip.path)).to contain_exactly(
      "prompt.txt",
      "README.md",
      "references/brand_base.png",
      "references/pack_sheet.png"
    )
    Zip::File.open(zip.path) do |archive|
      expect(archive.read("prompt.txt")).to eq("Designer prompt")
      expect(archive.read("README.md")).to include("Stamp #1")
      expect(archive.read("references/brand_base.png")).to eq("brand image")
      expect(archive.read("references/pack_sheet.png")).to eq("pack image")
    end
  end

  it "omits reference images when they are not attached" do
    zip = described_class.new(stamp).export

    expect(zip_entries(zip.path)).to contain_exactly("prompt.txt", "README.md")
  end

  it "builds a deterministic filename" do
    expect(described_class.new(stamp).filename).to eq("designer_kit_kit_brand_kit_pack_01.zip")
  end
end
