# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Linestamp join table uniqueness", type: :model do
  let!(:brand) { Linestamp::Brand.create!(slug: "uniq_brand", character_name: "Test", series_name: "Test") }
  let!(:pack) { brand.packs.create!(series_theme: "Theme", position: 1) }
  let!(:stamp) { pack.stamps.create!(position: 1) }
  let!(:theme) { Linestamp::CommunicationTheme.create!(slug: "uniq_theme", name: "Uniq Theme") }
  let!(:axis) { Linestamp::AttributeAxis.create!(slug: "uniq_axis", name: "Uniq", kind: "tone") }
  let!(:value) { Linestamp::AttributeValue.create!(axis: axis, slug: "uniq_val", name: "Uniq Val") }

  it "prevents duplicate brand-theme joins" do
    Linestamp::BrandCommunicationTheme.create!(brand: brand, communication_theme: theme)
    expect {
      Linestamp::BrandCommunicationTheme.create!(brand: brand, communication_theme: theme)
    }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "prevents duplicate brand-attribute joins" do
    Linestamp::BrandAttributeValue.create!(brand: brand, attribute_value: value)
    expect {
      Linestamp::BrandAttributeValue.create!(brand: brand, attribute_value: value)
    }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "prevents duplicate pack-theme joins" do
    Linestamp::PackCommunicationTheme.create!(pack: pack, communication_theme: theme)
    expect {
      Linestamp::PackCommunicationTheme.create!(pack: pack, communication_theme: theme)
    }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "prevents duplicate stamp-theme joins" do
    Linestamp::StampCommunicationTheme.create!(stamp: stamp, communication_theme: theme, primary: true)
    expect {
      Linestamp::StampCommunicationTheme.create!(stamp: stamp, communication_theme: theme)
    }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "prevents duplicate stamp-attribute joins" do
    Linestamp::StampAttributeValue.create!(stamp: stamp, attribute_value: value)
    expect {
      Linestamp::StampAttributeValue.create!(stamp: stamp, attribute_value: value)
    }.to raise_error(ActiveRecord::RecordInvalid)
  end
end
