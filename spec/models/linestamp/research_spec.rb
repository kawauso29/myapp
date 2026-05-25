require "rails_helper"

RSpec.describe Linestamp::Research, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:title) }
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
