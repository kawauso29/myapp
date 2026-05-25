require "rails_helper"

RSpec.describe Linestamp::Submission, type: :model do
  let(:brand) { Linestamp::Brand.create!(slug: "test-brand", name: "Test Brand") }
  let(:pack) { brand.packs.create!(title: "Pack 1", position: 1) }

  describe "associations" do
    it { is_expected.to belong_to(:pack) }
  end

  describe "AASM states" do
    let(:submission) { pack.submissions.create! }

    it "starts as draft" do
      expect(submission).to be_draft
    end

    it "transitions draft -> submitted" do
      submission.submit!
      expect(submission).to be_submitted
      expect(submission.submitted_at).not_to be_nil
    end

    it "transitions submitted -> approved" do
      submission.submit!
      submission.approve!
      expect(submission).to be_approved
      expect(submission.approved_at).not_to be_nil
    end

    it "transitions submitted -> rejected" do
      submission.submit!
      submission.reject!
      expect(submission).to be_rejected
      expect(submission.rejected_at).not_to be_nil
    end
  end
end
