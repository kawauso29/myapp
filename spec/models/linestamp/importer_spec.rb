# frozen_string_literal: true

require "rails_helper"

RSpec.describe Linestamp::Importer do
  before do
    # Ensure masters are seeded
    load Rails.root.join("db/seeds/linestamp/masters.rb")
    Linestamp::Seeds.call
  end

  describe ".run" do
    it "returns an Importer instance with summary" do
      result = described_class.run(seed_id: "test_run_001") do
        # no-op
      end
      expect(result).to be_a(described_class)
      expect(result.summary).to eq({ brands: 0, packs: 0, stamps: 0, researches: 0 })
    end
  end

  describe "#upsert_brand!" do
    it "creates a brand and sets imported_from/synced_at" do
      result = described_class.run(seed_id: "test_brand_001") do
        upsert_brand!(
          slug: "test_brand",
          character_name: "Test Char",
          series_name: "Test Series"
        )
      end

      brand = Linestamp::Brand.find_by(slug: "test_brand")
      expect(brand).to be_present
      expect(brand.imported_from).to eq("test_brand_001")
      expect(brand.synced_at).to be_within(5.seconds).of(Time.current)
      expect(result.summary[:brands]).to eq(1)
    end

    it "is idempotent - same seed_id does not duplicate" do
      2.times do
        described_class.run(seed_id: "test_brand_idem") do
          upsert_brand!(slug: "idem_brand", character_name: "C", series_name: "S")
        end
      end
      expect(Linestamp::Brand.where(slug: "idem_brand").count).to eq(1)
    end
  end

  describe "#upsert_brand! with research_slug (Research→Brand lineage)" do
    let!(:research) do
      Linestamp::Research.find_or_create_by!(slug: "lineage_research") do |r|
        r.title = "Lineage Research"
      end
    end

    it "links the brand to the research identified by research_slug" do
      described_class.run(seed_id: "test_brand_lineage") do
        upsert_brand!(
          slug: "lineage_brand",
          research_slug: "lineage_research",
          character_name: "Lineage Char",
          series_name: "Lineage Series"
        )
      end

      brand = Linestamp::Brand.find_by(slug: "lineage_brand")
      expect(brand.research).to eq(research)
      expect(brand.research_id).to eq(research.id)
    end

    it "raises ArgumentError for an unknown research_slug" do
      expect {
        described_class.run(seed_id: "test_brand_bad_research") do
          upsert_brand!(
            slug: "orphan_brand",
            research_slug: "does_not_exist",
            character_name: "Orphan",
            series_name: "Orphan Series"
          )
        end
      }.to raise_error(ArgumentError, /Unknown Research slug/)
    end

    it "creates a brand with no research when research_slug is omitted" do
      described_class.run(seed_id: "test_brand_no_research") do
        upsert_brand!(
          slug: "no_research_brand",
          character_name: "No Research",
          series_name: "No Research Series"
        )
      end

      brand = Linestamp::Brand.find_by(slug: "no_research_brand")
      expect(brand).to be_present
      expect(brand.research).to be_nil
    end
  end

  describe "#upsert_research!" do
    it "creates research with communication_themes and attributes" do
      described_class.run(seed_id: "test_research_001") do
        upsert_research!(
          slug: "test_research",
          title: "Test Research",
          communication_themes: %w[gratitude encouragement],
          attributes: { tone: %w[gentle cute] }
        )
      end

      research = Linestamp::Research.find_by(slug: "test_research")
      expect(research).to be_present
      expect(research.communication_themes.pluck(:slug)).to contain_exactly("gratitude", "encouragement")
      expect(research.attribute_values.pluck(:slug)).to contain_exactly("gentle", "cute")
    end
  end

  describe "unknown slug handling" do
    it "raises ArgumentError for unknown CommunicationTheme slug" do
      expect {
        described_class.run(seed_id: "test_unknown_ct") do
          upsert_research!(
            slug: "bad_research",
            title: "Bad",
            communication_themes: %w[nonexistent_theme]
          )
        end
      }.to raise_error(ArgumentError, /Unknown CommunicationTheme slug/)
    end

    it "raises ArgumentError for unknown AttributeValue slug" do
      expect {
        described_class.run(seed_id: "test_unknown_av") do
          upsert_research!(
            slug: "bad_research2",
            title: "Bad",
            attributes: { tone: %w[nonexistent_value] }
          )
        end
      }.to raise_error(ArgumentError, /Unknown AttributeValue/)
    end
  end

  describe "#create_pack! with stamps" do
    let!(:brand) do
      Linestamp::Brand.find_or_create_by!(slug: "pack_test_brand") do |b|
        b.character_name = "Pack Test"
        b.series_name = "Pack Test Series"
      end
    end

    it "creates a pack with stamps and sets primary_communication_theme" do
      test_brand = brand
      described_class.run(seed_id: "test_pack_001") do
        create_pack!(
          brand: Linestamp::Brand.find_by!(slug: "pack_test_brand"),
          slug: "test_pack",
          series_theme: "Test Theme",
          position: 1,
          purchase_unit_size: 8,
          communication_themes: %w[gratitude],
          attributes: { tone: %w[gentle] },
          stamps: [
            {
              label: "Stamp 1",
              primary_communication_theme: "greeting_morning",
              communication_themes: %w[encouragement],
              attributes: { tone: %w[cute] }
            },
            {
              label: "Stamp 2",
              primary_communication_theme: "gratitude",
              attributes: { setting: %w[home] }
            }
          ]
        )
      end

      pack = Linestamp::Pack.find_by(slug: "test_pack", brand: test_brand)
      expect(pack).to be_present
      expect(pack.stamps.count).to eq(2)
      expect(pack.communication_themes.pluck(:slug)).to include("gratitude")

      stamp1 = pack.stamps.find_by(position: 1)
      expect(stamp1.label).to eq("Stamp 1")
      expect(stamp1.primary_communication_theme.slug).to eq("greeting_morning")
      expect(stamp1.communication_themes.pluck(:slug)).to contain_exactly("greeting_morning", "encouragement")
    end

    it "is idempotent for packs and stamps" do
      brand # ensure created
      2.times do
        described_class.run(seed_id: "test_pack_idem") do
          create_pack!(
            brand: Linestamp::Brand.find_by!(slug: "pack_test_brand"),
            slug: "idem_pack",
            series_theme: "Idem",
            position: 2,
            purchase_unit_size: 8,
            stamps: [
              { label: "S1", primary_communication_theme: "gratitude" }
            ]
          )
        end
      end
      expect(Linestamp::Pack.where(slug: "idem_pack", brand: brand).count).to eq(1)
      expect(Linestamp::Pack.find_by(slug: "idem_pack", brand: brand).stamps.count).to eq(1)
    end
  end
end
