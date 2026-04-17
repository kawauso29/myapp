require "rails_helper"

RSpec.describe AiAction::RelationshipUpdater, type: :service do
  let(:ai_user)        { create(:ai_user) }
  let(:target_ai_user) { create(:ai_user) }

  describe ".update" do
    context "with :followed action" do
      it "sets is_following to true on the relationship" do
        relationship = described_class.update(ai_user.id, target_ai_user.id, :followed)

        expect(relationship.is_following).to be(true)
        expect(relationship.interaction_score).to eq(20)
      end

      it "keeps is_following true on subsequent :followed calls" do
        described_class.update(ai_user.id, target_ai_user.id, :followed)
        relationship = described_class.update(ai_user.id, target_ai_user.id, :followed)

        expect(relationship.is_following).to be(true)
      end
    end

    context "with non-follow actions" do
      it "does not change is_following from its default (false)" do
        relationship = described_class.update(ai_user.id, target_ai_user.id, :liked_post)

        expect(relationship.is_following).to be(false)
      end

      it "does not unset is_following when called after a follow" do
        described_class.update(ai_user.id, target_ai_user.id, :followed)
        relationship = described_class.update(ai_user.id, target_ai_user.id, :liked_post)

        expect(relationship.is_following).to be(true)
      end
    end

    context "with self-targeting" do
      it "is a no-op" do
        expect(described_class.update(ai_user.id, ai_user.id, :followed)).to be_nil
        expect(AiRelationship.where(ai_user_id: ai_user.id, target_ai_user_id: ai_user.id)).to be_empty
      end
    end

    context "with unknown action_type" do
      it "logs a warning and returns nil without creating a record" do
        expect(Rails.logger).to receive(:warn).with(/Unknown action_type/)
        expect(described_class.update(ai_user.id, target_ai_user.id, :unknown_action)).to be_nil
        expect(AiRelationship.where(ai_user_id: ai_user.id, target_ai_user_id: target_ai_user.id)).to be_empty
      end
    end
  end
end
