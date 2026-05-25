require "rails_helper"

RSpec.describe Linestamp::PromptComposer do
  let(:brand) { Linestamp::Brand.create!(slug: "nemuinu", name: "ねむ犬", description: "眠そうな犬") }
  let(:pack) { brand.packs.create!(title: "vol.1", position: 1) }
  let(:stamp) { pack.stamps.create!(position: 1, emotion: "happy", text_overlay: "やったー！") }
  let(:composer) { described_class.new }

  describe "#compose_brand_prompt" do
    it "returns a prompt containing brand info" do
      prompt = composer.compose_brand_prompt(brand)
      expect(prompt).to include("ねむ犬")
      expect(prompt).to include("眠そうな犬")
    end
  end

  describe "#compose_pack_sheet_prompt" do
    before { brand.update!(brand_prompt: "Brand prompt text") }

    it "returns a prompt containing pack and brand info" do
      prompt = composer.compose_pack_sheet_prompt(pack)
      expect(prompt).to include("ねむ犬")
      expect(prompt).to include("vol.1")
      expect(prompt).to include("Brand prompt text")
    end
  end

  describe "#compose_stamp_prompt" do
    before { brand.update!(brand_prompt: "Brand prompt text") }

    it "returns a prompt containing stamp details" do
      prompt = composer.compose_stamp_prompt(stamp)
      expect(prompt).to include("happy")
      expect(prompt).to include("やったー！")
      expect(prompt).to include("370x320")
    end
  end
end
