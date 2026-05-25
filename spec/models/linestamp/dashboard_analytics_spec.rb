# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin Linestamp Dashboard analytics", type: :model do
  before do
    brand = Linestamp::Brand.create!(slug: "dash_brand", character_name: "Test", series_name: "Test")
    axis = Linestamp::AttributeAxis.create!(slug: "dash_tone", name: "トーン", kind: "tone")
    gentle = Linestamp::AttributeValue.create!(axis: axis, slug: "dash_gentle", name: "ゆるい")
    theme = Linestamp::CommunicationTheme.create!(slug: "dash_gratitude", name: "感謝")

    pack1 = brand.packs.create!(series_theme: "P1", position: 1, published_at: 1.day.ago, sales_count: 50)
    pack2 = brand.packs.create!(series_theme: "P2", position: 2, published_at: 2.days.ago, sales_count: 30)
    unpub = brand.packs.create!(series_theme: "P3", position: 3, sales_count: 100)

    pack1.pack_attribute_values.create!(attribute_value: gentle)
    pack2.pack_attribute_values.create!(attribute_value: gentle)
    pack1.pack_communication_themes.create!(communication_theme: theme)
    pack2.pack_communication_themes.create!(communication_theme: theme)
    # unpublished pack has attribute but should NOT count in published-only analytics
    unpub.pack_attribute_values.create!(attribute_value: gentle)
  end

  it "computes attribute sales sum for published packs only" do
    result = Linestamp::AttributeValue
      .joins(:axis, :pack_attribute_values)
      .joins("INNER JOIN linestamp_packs ON linestamp_packs.id = linestamp_pack_attribute_values.pack_id")
      .where.not(linestamp_packs: { published_at: nil })
      .group("linestamp_attribute_axes.name", "linestamp_attribute_values.name")
      .sum("linestamp_packs.sales_count")

    expect(result[["トーン", "ゆるい"]]).to eq(80) # 50 + 30 (unpublished excluded)
  end

  it "computes theme sales sum for published packs only" do
    result = Linestamp::CommunicationTheme
      .joins(:pack_communication_themes)
      .joins("INNER JOIN linestamp_packs ON linestamp_packs.id = linestamp_pack_communication_themes.pack_id")
      .where.not(linestamp_packs: { published_at: nil })
      .group("linestamp_communication_themes.name")
      .sum("linestamp_packs.sales_count")

    expect(result["感謝"]).to eq(80)
  end
end
