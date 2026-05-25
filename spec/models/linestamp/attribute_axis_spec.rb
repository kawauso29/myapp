# frozen_string_literal: true

require "rails_helper"

RSpec.describe Linestamp::AttributeAxis, type: :model do
  describe "validations" do
    subject { described_class.new(slug: "tone", name: "トーン", kind: "tone") }

    it { is_expected.to validate_presence_of(:slug) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:kind) }
    it { is_expected.to validate_uniqueness_of(:slug) }
    it { is_expected.to validate_inclusion_of(:kind).in_array(Linestamp::AttributeAxis::KINDS) }
  end

  describe "associations" do
    it { is_expected.to have_many(:attribute_values).dependent(:destroy) }
  end
end
