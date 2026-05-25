# frozen_string_literal: true

require "rails_helper"

RSpec.describe Linestamp::AttributeValue, type: :model do
  let!(:axis) { Linestamp::AttributeAxis.create!(slug: "tone", name: "トーン", kind: "tone") }

  describe "validations" do
    subject { described_class.new(axis: axis, slug: "gentle", name: "ゆるい") }

    it { is_expected.to validate_presence_of(:slug) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:slug).scoped_to(:axis_id) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:axis) }
    it { is_expected.to have_many(:brand_attribute_values).dependent(:destroy) }
    it { is_expected.to have_many(:pack_attribute_values).dependent(:destroy) }
    it { is_expected.to have_many(:stamp_attribute_values).dependent(:destroy) }
  end
end
