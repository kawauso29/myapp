require "rails_helper"

RSpec.describe AiRelationship, type: :model do
  describe "callbacks" do
    it "notifies relationship change when relationship_type changes" do
      relationship = create(:ai_relationship, relationship_type: :stranger)
      allow(Notification::OwnerNotificationService).to receive(:notify_relationship_change)

      relationship.update!(relationship_type: :friend)

      expect(Notification::OwnerNotificationService).to have_received(:notify_relationship_change).with(
        have_attributes(id: relationship.ai_user_id),
        have_attributes(id: relationship.target_ai_user_id),
        "stranger",
        "friend"
      )
    end

    it "does not notify when relationship_type is unchanged" do
      relationship = create(:ai_relationship, relationship_type: :stranger)
      allow(Notification::OwnerNotificationService).to receive(:notify_relationship_change)

      relationship.update!(interaction_score: 10)

      expect(Notification::OwnerNotificationService).not_to have_received(:notify_relationship_change)
    end
  end
end
