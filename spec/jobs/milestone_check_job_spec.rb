require "rails_helper"

RSpec.describe MilestoneCheckJob, type: :job do
  before do
    Rails.cache.clear
    allow(Notification::OwnerNotificationService).to receive(:notify_milestone)
  end

  describe "#perform" do
    let!(:ai) { create(:ai_user, is_active: true, followers_count: 0, posts_count: 0, total_likes: 0) }

    before do
      # テスト対象のAIのみを対象にする (シードデータの影響を排除)
      allow(AiUser).to receive(:active).and_return(AiUser.where(id: ai.id))
    end

    context "フォロワー数マイルストーン" do
      it "フォロワー10人達成で通知が送られる" do
        ai.update_columns(followers_count: 10)

        described_class.new.perform

        expect(Notification::OwnerNotificationService)
          .to have_received(:notify_milestone).with(ai, "followers_10", 10)
      end

      it "同じマイルストーンは2回通知されない" do
        ai.update_columns(followers_count: 10)

        # 1回目のキャッシュヒットをシミュレート
        cache_key = "milestone_notified:#{ai.id}:followers_10"
        allow(Rails.cache).to receive(:exist?).and_return(false)
        allow(Rails.cache).to receive(:exist?).with(cache_key).and_return(false, true)
        allow(Rails.cache).to receive(:write)

        described_class.new.perform
        described_class.new.perform

        expect(Notification::OwnerNotificationService)
          .to have_received(:notify_milestone).with(ai, "followers_10", 10).once
      end

      it "フォロワー数が閾値未満の場合は通知されない" do
        ai.update_columns(followers_count: 5)

        described_class.new.perform

        expect(Notification::OwnerNotificationService).not_to have_received(:notify_milestone)
      end
    end

    context "初投稿マイルストーン" do
      it "posts_count >= 1 で first_post 通知が送られる" do
        ai.update_columns(posts_count: 1)

        described_class.new.perform

        expect(Notification::OwnerNotificationService)
          .to have_received(:notify_milestone).with(ai, "first_post", 1)
      end

      it "posts_count == 0 では通知されない" do
        ai.update_columns(posts_count: 0)

        described_class.new.perform

        expect(Notification::OwnerNotificationService)
          .not_to have_received(:notify_milestone).with(ai, "first_post", anything)
      end

      it "初投稿は一度だけ通知される" do
        ai.update_columns(posts_count: 5)

        cache_key = "milestone_notified:#{ai.id}:first_post"
        allow(Rails.cache).to receive(:exist?).and_return(false)
        allow(Rails.cache).to receive(:exist?).with(cache_key).and_return(false, true)
        allow(Rails.cache).to receive(:write)

        described_class.new.perform
        described_class.new.perform

        expect(Notification::OwnerNotificationService)
          .to have_received(:notify_milestone).with(ai, "first_post", 1).once
      end
    end

    context "いいね数マイルストーン" do
      it "100いいね達成で likes_100 通知が送られる" do
        ai.update_columns(total_likes: 100)

        described_class.new.perform

        expect(Notification::OwnerNotificationService)
          .to have_received(:notify_milestone).with(ai, "likes_100", 100)
      end

      it "99いいねでは通知されない" do
        ai.update_columns(total_likes: 99)

        described_class.new.perform

        expect(Notification::OwnerNotificationService)
          .not_to have_received(:notify_milestone).with(ai, "likes_100", anything)
      end
    end

    context "初めての友達マイルストーン" do
      it "friend 関係があると first_friend 通知が送られる" do
        other_ai = create(:ai_user)
        create(:ai_relationship, ai_user: ai, target_ai_user: other_ai, relationship_type: :friend)

        described_class.new.perform

        expect(Notification::OwnerNotificationService)
          .to have_received(:notify_milestone).with(ai, "first_friend", 1)
      end

      it "acquaintance 関係だけでは通知されない" do
        other_ai = create(:ai_user)
        create(:ai_relationship, ai_user: ai, target_ai_user: other_ai, relationship_type: :acquaintance)

        described_class.new.perform

        expect(Notification::OwnerNotificationService)
          .not_to have_received(:notify_milestone).with(ai, "first_friend", anything)
      end
    end

    context "初恋マイルストーン" do
      it "close_friend 関係があると first_love 通知が送られる" do
        other_ai = create(:ai_user)
        create(:ai_relationship, ai_user: ai, target_ai_user: other_ai, relationship_type: :close_friend)

        described_class.new.perform

        expect(Notification::OwnerNotificationService)
          .to have_received(:notify_milestone).with(ai, "first_love", 1)
      end

      it "friend 関係だけでは first_love は通知されない" do
        other_ai = create(:ai_user)
        create(:ai_relationship, ai_user: ai, target_ai_user: other_ai, relationship_type: :friend)

        described_class.new.perform

        expect(Notification::OwnerNotificationService)
          .not_to have_received(:notify_milestone).with(ai, "first_love", anything)
      end

      it "close_friend があると first_friend と first_love 両方通知される" do
        other_ai = create(:ai_user)
        create(:ai_relationship, ai_user: ai, target_ai_user: other_ai, relationship_type: :close_friend)

        described_class.new.perform

        expect(Notification::OwnerNotificationService)
          .to have_received(:notify_milestone).with(ai, "first_friend", 1)
        expect(Notification::OwnerNotificationService)
          .to have_received(:notify_milestone).with(ai, "first_love", 1)
      end
    end

    context "非アクティブなAI" do
      it "is_active: false のAIはスキップされる" do
        inactive = create(:ai_user, is_active: false, posts_count: 1)
        allow(AiUser).to receive(:active).and_return(AiUser.where(id: inactive.id).none)

        described_class.new.perform

        expect(Notification::OwnerNotificationService)
          .not_to have_received(:notify_milestone)
      end
    end
  end
end
