require "rails_helper"

RSpec.describe MilestoneCheckJob, type: :job do
  let(:user) { create(:user) }
  let(:ai) { create(:ai_user) }

  before do
    UserFavoriteAi.create!(user: user, ai_user: ai)
    allow(Notification::ExpoNotificationService).to receive(:send_bulk)
    allow(UserNotificationChannel).to receive(:broadcast_to)
  end

  describe "#perform" do
    context "follower milestones" do
      it "fires followers_10 milestone when followers_count >= 10" do
        ai.update!(followers_count: 10)

        expect {
          described_class.perform_now
        }.to change(UserNotification, :count).by(1)

        notification = UserNotification.last
        expect(notification.notification_type).to eq("milestone")
        expect(notification.metadata["milestone"]).to eq("followers_10")
      end

      it "does not fire followers_10 twice when cache prevents it" do
        ai.update!(followers_count: 10)
        cache_key = "milestone_notified:#{ai.id}:followers:10"
        allow(Rails.cache).to receive(:exist?) { |key| key == cache_key }
        allow(Rails.cache).to receive(:write)

        expect {
          described_class.perform_now
        }.not_to change(UserNotification.where("metadata->>'milestone' = 'followers_10'"), :count)
      end

      it "does not fire milestone when below threshold" do
        ai.update!(followers_count: 5)

        expect {
          described_class.perform_now
        }.not_to change(UserNotification, :count)
      end
    end

    context "likes milestones" do
      it "fires total_likes_100 when total_likes >= 100" do
        ai.update!(total_likes: 100)

        expect {
          described_class.perform_now
        }.to change(UserNotification, :count).by(1)

        notification = UserNotification.last
        expect(notification.metadata["milestone"]).to eq("total_likes_100")
      end

      it "fires multiple likes milestones when total_likes reaches multiple thresholds" do
        ai.update!(total_likes: 500)

        expect {
          described_class.perform_now
        }.to change(UserNotification, :count).by(2) # 100 and 500
      end

      it "does not fire likes milestone when below threshold" do
        ai.update!(total_likes: 99)

        expect {
          described_class.perform_now
        }.not_to change(UserNotification, :count)
      end
    end

    context "first_post milestone" do
      it "fires first_post milestone when posts_count >= 1" do
        ai.update!(posts_count: 1)

        expect {
          described_class.perform_now
        }.to change(UserNotification, :count).by(1)

        notification = UserNotification.last
        expect(notification.notification_type).to eq("milestone")
        expect(notification.metadata["milestone"]).to eq("first_post")
        expect(notification.message).to include("初めての投稿")
      end

      it "does not fire first_post when posts_count is 0" do
        ai.update!(posts_count: 0)

        expect {
          described_class.perform_now
        }.not_to change(UserNotification, :count)
      end
    end

    context "first_friend milestone" do
      it "fires first_friend milestone when AI has a friend relationship" do
        other_ai = create(:ai_user)
        create(:ai_relationship, ai_user: ai, target_ai_user: other_ai, relationship_type: :friend)

        expect {
          described_class.perform_now
        }.to change(UserNotification, :count).by(1)

        notification = UserNotification.last
        expect(notification.metadata["milestone"]).to eq("first_friend")
        expect(notification.message).to include("友達")
      end

      it "fires first_friend and first_close_friend when AI has a close_friend relationship" do
        other_ai = create(:ai_user)
        create(:ai_relationship, ai_user: ai, target_ai_user: other_ai, relationship_type: :close_friend)

        expect {
          described_class.perform_now
        }.to change(UserNotification, :count).by(2)

        milestones = UserNotification.where("metadata->>'milestone' IN ('first_friend', 'first_close_friend')")
                                     .pluck(Arel.sql("metadata->>'milestone'"))
        expect(milestones).to include("first_friend", "first_close_friend")
      end

      it "does not fire first_friend when only stranger/acquaintance relationships exist" do
        other_ai = create(:ai_user)
        create(:ai_relationship, ai_user: ai, target_ai_user: other_ai, relationship_type: :acquaintance)

        expect {
          described_class.perform_now
        }.not_to change(UserNotification, :count)
      end
    end

    context "first_close_friend milestone" do
      it "fires first_close_friend milestone when AI has a close_friend relationship" do
        other_ai = create(:ai_user)
        create(:ai_relationship, ai_user: ai, target_ai_user: other_ai, relationship_type: :close_friend)

        described_class.perform_now

        notification = UserNotification.where("metadata->>'milestone' = 'first_close_friend'").last
        expect(notification).to be_present
        expect(notification.message).to include("親友")
      end

      it "does not fire first_close_friend when only friend relationship exists" do
        other_ai = create(:ai_user)
        create(:ai_relationship, ai_user: ai, target_ai_user: other_ai, relationship_type: :friend)

        described_class.perform_now

        close_friend_notification = UserNotification.where("metadata->>'milestone' = 'first_close_friend'").last
        expect(close_friend_notification).to be_nil
      end
    end

    context "with inactive AI" do
      it "skips inactive AI users" do
        ai.update!(is_active: false, posts_count: 10, total_likes: 200)

        expect {
          described_class.perform_now
        }.not_to change(UserNotification, :count)
      end
    end
  end
end
