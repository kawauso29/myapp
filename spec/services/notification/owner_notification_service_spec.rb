require "rails_helper"

RSpec.describe Notification::OwnerNotificationService, type: :service do
  describe ".notify_relationship_change" do
    let(:ai_user) { create(:ai_user) }
    let(:target_ai_user) { create(:ai_user) }
    let(:user) { create(:user) }

    before do
      UserFavoriteAi.create!(user: user, ai_user: ai_user)
      allow(Notification::ExpoNotificationService).to receive(:send_bulk)
      allow(UserNotificationChannel).to receive(:broadcast_to)
    end

    it "creates a UserNotification record for favorited users" do
      expect {
        described_class.notify_relationship_change(ai_user, target_ai_user, "stranger", "friend")
      }.to change(UserNotification, :count).by(1)

      notification = UserNotification.last
      expect(notification.notification_type).to eq("relationship_change")
      expect(notification.ai_user).to eq(ai_user)
      expect(notification.target_ai_user_id).to eq(target_ai_user.id)
      expect(notification.metadata["old_type"]).to eq("stranger")
      expect(notification.metadata["new_type"]).to eq("friend")
    end

    it "broadcasts via ActionCable to favorited users" do
      described_class.notify_relationship_change(ai_user, target_ai_user, "stranger", "friend")

      expect(UserNotificationChannel).to have_received(:broadcast_to).with(
        user,
        hash_including(type: "relationship_change", old_type: "stranger", new_type: "friend")
      )
    end

    it "sends an Expo push notification" do
      described_class.notify_relationship_change(ai_user, target_ai_user, "stranger", "friend")

      expect(Notification::ExpoNotificationService).to have_received(:send_bulk).with(
        hash_including(title: "関係性の変化")
      )
    end

    it "does not create notifications when no users favorite either AI" do
      other_ai_user = create(:ai_user)
      other_target_ai_user = create(:ai_user)

      expect {
        described_class.notify_relationship_change(other_ai_user, other_target_ai_user, "stranger", "friend")
      }.not_to change(UserNotification, :count)
    end

    context "with upgrade in relationship type" do
      it "includes a positive message for friend" do
        described_class.notify_relationship_change(ai_user, target_ai_user, "stranger", "friend")

        notification = UserNotification.last
        expect(notification.message).to include("友達になりました")
      end

      it "includes a positive message for close_friend" do
        described_class.notify_relationship_change(ai_user, target_ai_user, "friend", "close_friend")

        notification = UserNotification.last
        expect(notification.message).to include("親友になりました")
      end
    end

    context "with downgrade in relationship type" do
      it "includes a negative message for stranger" do
        described_class.notify_relationship_change(ai_user, target_ai_user, "friend", "stranger")

        notification = UserNotification.last
        expect(notification.message).to include("疎遠になりました")
      end
    end
  end

  describe ".notify_milestone" do
    let(:ai_user) { create(:ai_user) }
    let(:user) { create(:user) }

    before do
      UserFavoriteAi.create!(user: user, ai_user: ai_user)
      allow(Notification::ExpoNotificationService).to receive(:send_bulk)
      allow(UserNotificationChannel).to receive(:broadcast_to)
    end

    it "creates a UserNotification record with notification_type milestone" do
      expect {
        described_class.notify_milestone(ai_user, "followers_10", 10)
      }.to change(UserNotification, :count).by(1)

      notification = UserNotification.last
      expect(notification.notification_type).to eq("milestone")
      expect(notification.ai_user).to eq(ai_user)
      expect(notification.metadata["milestone"]).to eq("followers_10")
      expect(notification.metadata["value"]).to eq(10)
    end

    it "includes correct follower milestone message" do
      described_class.notify_milestone(ai_user, "followers_100", 100)

      notification = UserNotification.last
      expect(notification.message).to include("フォロワーが100人")
    end

    it "includes correct first_post milestone message" do
      described_class.notify_milestone(ai_user, "first_post", 1)

      notification = UserNotification.last
      expect(notification.message).to include("初めての投稿")
    end

    it "includes correct total_likes milestone message" do
      described_class.notify_milestone(ai_user, "total_likes_100", 100)

      notification = UserNotification.last
      expect(notification.message).to include("いいね数が100件")
    end

    it "includes correct first_friend milestone message" do
      described_class.notify_milestone(ai_user, "first_friend", 1)

      notification = UserNotification.last
      expect(notification.message).to include("友達")
    end

    it "includes correct first_close_friend milestone message" do
      described_class.notify_milestone(ai_user, "first_close_friend", 1)

      notification = UserNotification.last
      expect(notification.message).to include("親友")
    end

    it "broadcasts via ActionCable to favorited users" do
      described_class.notify_milestone(ai_user, "first_post", 1)

      expect(UserNotificationChannel).to have_received(:broadcast_to).with(
        user,
        hash_including(type: "milestone", milestone: "first_post")
      )
    end

    it "sends an Expo push notification" do
      described_class.notify_milestone(ai_user, "first_post", 1)

      expect(Notification::ExpoNotificationService).to have_received(:send_bulk).with(
        hash_including(data: hash_including(type: "milestone", milestone: "first_post"))
      )
    end

    it "does not create notifications when no users favorite the AI" do
      unfavorited_ai = create(:ai_user)

      expect {
        described_class.notify_milestone(unfavorited_ai, "first_post", 1)
      }.not_to change(UserNotification, :count)
    end
  end
end
