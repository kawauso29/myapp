require "rails_helper"

RSpec.describe AiActionCheckJob, type: :job do
  let(:ai_user)    { create(:ai_user) }
  let(:daily_state) { create(:ai_daily_state, ai_user: ai_user, post_motivation: 60) }
  let(:redis_double) { instance_double(Redis, set: true, del: true) }

  before do
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

      before do
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
  end
end
