require "rails_helper"

RSpec.describe Linestamp::Pack, type: :model do
  let(:brand) { Linestamp::Brand.create!(slug: "test-brand", name: "Test Brand") }

  describe "validations" do
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_presence_of(:position) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:brand) }
    it { is_expected.to have_many(:stamps) }
    it { is_expected.to have_many(:submissions) }
  end

  describe "AASM states" do
    let(:pack) { brand.packs.create!(title: "Pack 1", position: 1) }

    it "starts as planned" do
      expect(pack).to be_planned
    end

    it "transitions planned -> prompt_ready when sheet_prompt set" do
      pack.update!(sheet_prompt: "test prompt")
      pack.mark_prompt_ready!
      expect(pack).to be_prompt_ready
    end

    it "cannot transition to prompt_ready without sheet_prompt" do
      expect(pack.may_mark_prompt_ready?).to be false
    end
  end
end
