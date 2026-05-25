require "rails_helper"

RSpec.describe Linestamp::Seeders::Nemuinu do
  describe "#seed!" do
    it "creates nemuinu brand with pack and stamps" do
      brand = described_class.new.seed!

      expect(brand.slug).to eq("nemuinu")
      expect(brand.name).to eq("ねむ犬")
      expect(brand.packs.count).to eq(1)
      expect(brand.packs.first.stamps.count).to eq(8)
      expect(brand.packs.first.title).to eq("ねむ犬 vol.1 日常編")
    end

    it "is idempotent" do
      described_class.new.seed!
      described_class.new.seed!

      expect(Linestamp::Brand.where(slug: "nemuinu").count).to eq(1)
    end
  end
end
