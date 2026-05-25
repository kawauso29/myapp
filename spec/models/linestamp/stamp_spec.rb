require "rails_helper"

RSpec.describe Linestamp::Stamp, type: :model do
  let(:brand) { Linestamp::Brand.create!(slug: "test-brand", name: "Test Brand") }
  let(:pack) { brand.packs.create!(title: "Pack 1", position: 1) }

  describe "validations" do
    it { is_expected.to validate_presence_of(:position) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:pack) }
  end

  describe "AASM states" do
    let(:stamp) { pack.stamps.create!(position: 1) }

    it "starts as planned" do
      expect(stamp).to be_planned
    end

    it "transitions planned -> prompt_ready when prompt set" do
      stamp.update!(prompt: "test prompt")
      stamp.mark_prompt_ready!
      expect(stamp).to be_prompt_ready
    end

    it "cannot transition to prompt_ready without prompt" do
      expect(stamp.may_mark_prompt_ready?).to be false
    end
  end
end
