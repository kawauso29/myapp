require "rails_helper"

RSpec.describe AiActionCheckJob, type: :job do
  let(:ai_user)    { create(:ai_user) }
  let(:daily_state) { create(:ai_daily_state, ai_user: ai_user, post_motivation: 60) }
  let(:ai_users_to_process) { [ ai_user ] }
  let(:redis_double) { instance_double(Redis, set: true, del: true) }

  before do
    relation = instance_double(ActiveRecord::Relation)
    allow(AiUser).to receive(:where).with(is_active: true).and_return(relation)
    allow(relation).to receive(:find_each).with(batch_size: 100) do |&block|
      ai_users_to_process.each(&block)
    end

    allow(Redis).to receive(:new).and_return(redis_double)
    # Redisロック取得成功
    allow(redis_double).to receive(:set).with(AiActionCheckJob::LOCK_KEY, 1, nx: true, ex: anything).and_return(true)
    allow(ai_user).to receive(:today_state).and_return(daily_state)
    allow(AiAction::TimelineSelector).to receive(:select).and_return([])
    allow(SlackNotifierService).to receive(:notify)
  end

  describe "#perform" do
    context "when redis lock is already acquired" do
      before do
        allow(redis_double).to receive(:set).with(AiActionCheckJob::LOCK_KEY, 1, nx: true, ex: anything).and_return(nil)
      end

      it "skips processing" do
        expect(AiAction::TimelineSelector).not_to receive(:select)
        described_class.new.perform
      end
    end

    context "when AI is active with sufficient motivation" do
      it "reads the timeline" do
        described_class.new.perform
        expect(AiAction::TimelineSelector).to have_received(:select).with(ai_user, limit: 15)
      end
    end

    context "when AI is sick" do
      let(:daily_state) { create(:ai_daily_state, :sick, ai_user: ai_user) }

      it "skips the AI" do
        expect(AiAction::ActionChecker).not_to receive(:should_post?)
        described_class.new.perform
      end
    end

    context "when post_motivation is below 20" do
      let(:daily_state) { create(:ai_daily_state, ai_user: ai_user, post_motivation: 10) }

      it "skips the AI" do
        expect(AiAction::ActionChecker).not_to receive(:should_post?)
        described_class.new.perform
      end
    end

    context "when post_motivation is nil" do
      let(:daily_state) { create(:ai_daily_state, ai_user: ai_user, post_motivation: nil) }

      it "skips the AI without raising" do
        expect(AiAction::ActionChecker).not_to receive(:should_post?)
        expect { described_class.new.perform }.not_to raise_error
      end
    end

    context "when an interesting post is found and should_reply is true" do
      let(:target_ai)   { create(:ai_user) }
      let(:target_post) { create(:ai_post, ai_user: target_ai) }
      let(:post_tag)    { create(:ai_post, ai_user: target_ai, likes_count: 15) }

      before do
        allow(AiAction::TimelineSelector).to receive(:select).and_return([ post_tag ])
        allow_any_instance_of(described_class).to receive(:should_reply?).and_return(true)
        allow(ReplyGenerateJob).to receive(:perform_later)
      end

      it "enqueues ReplyGenerateJob" do
        described_class.new.perform
        expect(ReplyGenerateJob).to have_received(:perform_later).with(ai_user.id, post_tag.id)
      end
    end

    context "when no interesting post and should_post is true" do
      before do
        allow(AiAction::ActionChecker).to receive(:should_post?).and_return(true)
        allow(AiAction::MotivationSelector).to receive(:select).and_return({ primary: :sharing })
        allow(PostGenerateJob).to receive(:perform_later)
      end

      it "enqueues PostGenerateJob" do
        described_class.new.perform
        expect(PostGenerateJob).to have_received(:perform_later).with(ai_user.id, { primary: :sharing })
      end
    end

    context "when processing raises an error for one AI" do
      let!(:other_ai) { create(:ai_user) }
      let!(:other_daily_state) { create(:ai_daily_state, ai_user: other_ai, post_motivation: 60) }
      let(:ai_users_to_process) { [ ai_user, other_ai ] }

      before do
        allow(other_ai).to receive(:today_state).and_return(other_daily_state)
        call_count = 0
        allow(AiAction::TimelineSelector).to receive(:select) do
          call_count += 1
          raise StandardError, "boom" if call_count == 1
          []
        end
      end

      it "continues processing remaining AIs" do
        expect { described_class.new.perform }.not_to raise_error
        expect(AiAction::TimelineSelector).to have_received(:select).twice
      end
    end

    context "when action scope is like only" do
      before do
        allow(AiAction::ActionChecker).to receive(:should_post?).and_return(true)
      end

      it "only runs timeline like check" do
        described_class.new.perform("like")
        expect(AiAction::TimelineSelector).to have_received(:select).with(ai_user, limit: 15)
        expect(AiAction::ActionChecker).not_to have_received(:should_post?)
      end
    end

    context "when action scope is reply only" do
      let(:target_ai) { create(:ai_user) }
      let(:target_post) { create(:ai_post, ai_user: target_ai, likes_count: 20) }

      before do
        allow(AiAction::TimelineSelector).to receive(:select).and_return([ target_post ])
        allow_any_instance_of(described_class).to receive(:should_reply?).and_return(true)
        allow(ReplyGenerateJob).to receive(:perform_later)
        allow(AiAction::ActionChecker).to receive(:should_post?).and_return(true)
      end

      it "enqueues only reply job" do
        described_class.new.perform("reply")
        expect(ReplyGenerateJob).to have_received(:perform_later).with(ai_user.id, target_post.id)
        expect(AiAction::ActionChecker).not_to have_received(:should_post?)
      end
    end

    context "when action scope is post only" do
      before do
        allow(AiAction::ActionChecker).to receive(:should_post?).and_return(true)
        allow(AiAction::MotivationSelector).to receive(:select).and_return({ primary: :sharing })
        allow(PostGenerateJob).to receive(:perform_later)
      end

      it "enqueues post generation without timeline read" do
        described_class.new.perform("post")
        expect(AiAction::TimelineSelector).not_to have_received(:select)
        expect(PostGenerateJob).to have_received(:perform_later).with(ai_user.id, { primary: :sharing })
      end
    end

    context "when action scope is dm only" do
      before do
        allow_any_instance_of(described_class).to receive(:should_dm?).and_return(true)
        allow(DmCheckJob).to receive(:perform_later)
      end

      it "enqueues dm check job" do
        described_class.new.perform("dm")
        expect(DmCheckJob).to have_received(:perform_later).with(ai_user.id)
        expect(AiAction::TimelineSelector).not_to have_received(:select)
      end
    end
  end
end
