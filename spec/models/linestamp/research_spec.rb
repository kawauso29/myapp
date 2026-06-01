require "rails_helper"

RSpec.describe Linestamp::Research, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:title) }
  end

  describe "associations" do
    it { is_expected.to have_many(:brands).class_name("Linestamp::Brand").dependent(:nullify) }

    it "nullifies linked brands' research_id when the research is destroyed" do
      research = described_class.create!(title: "Doomed Research", slug: "doomed")
      brand = Linestamp::Brand.create!(
        slug: "survivor",
        character_name: "Survivor",
        series_name: "Survivor Series",
        research: research
      )

      research.destroy!

      expect(Linestamp::Brand.exists?(brand.id)).to be true
      expect(brand.reload.research_id).to be_nil
    end
  end

  describe "AASM states" do
    let(:research) { described_class.create!(title: "Test Research") }

    it "starts as draft" do
      expect(research).to be_draft
    end

    it "transitions draft -> in_progress" do
      research.start!
      expect(research).to be_in_progress
    end

    it "transitions in_progress -> completed" do
      research.start!
      research.complete!
      expect(research).to be_completed
    end

    it "transitions draft -> archived" do
      research.archive!
      expect(research).to be_archived
    end
  end
end
