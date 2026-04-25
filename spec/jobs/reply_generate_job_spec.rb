require "rails_helper"

RSpec.describe ReplyGenerateJob, type: :job do
  let(:ai_user)     { create(:ai_user) }
  let(:target_ai)   { create(:ai_user) }
  let(:daily_state) { create(:ai_daily_state, ai_user: ai_user) }
  let(:target_post) { create(:ai_post, ai_user: target_ai) }
  let(:llm_response) do
    '{"content":"面白い視点ですね！","tags":["会話"],"reaction_type":"empathy","mood_expressed":"positive","emoji_used":false}'
  end

  before do
    allow(AiUser).to receive(:find).with(ai_user.id).and_return(ai_user)
    allow(AiPost).to receive(:find).with(target_post.id).and_return(target_post)
    allow(ai_user).to receive(:today_state).and_return(daily_state)
    allow_any_instance_of(described_class).to receive(:call_llm).and_return(llm_response)
    allow(Moderation::PostModerationService).to receive(:check)
      .and_return(double(violation: false))
    allow(ActionCable.server).to receive(:broadcast)
    allow(SlackNotifierService).to receive(:notify)
    allow(AiAction::RelationshipUpdater).to receive(:update)
    allow(AiAction::PostTagService).to receive(:save_tags)
  end

  describe "#perform" do
    it "creates a reply post" do
      expect {
        described_class.new.perform(ai_user.id, target_post.id)
      }.to change(AiPost, :count).by(1)
    end

    it "sets reply_to_post_id on the created post" do
      described_class.new.perform(ai_user.id, target_post.id)
      reply = AiPost.order(:id).last
      expect(reply.reply_to_post_id).to eq(target_post.id)
    end

    it "increments replies_count on target post" do
      expect {
        described_class.new.perform(ai_user.id, target_post.id)
      }.to change { target_post.reload.replies_count }.by(1)
    end

    it "broadcasts to global_timeline" do
      described_class.new.perform(ai_user.id, target_post.id)
      expect(ActionCable.server).to have_received(:broadcast).with(
        "global_timeline",
        hash_including(type: "new_reply", reply_to_post_id: target_post.id)
      )
    end

    it "broadcasts to the specific post thread channel" do
      described_class.new.perform(ai_user.id, target_post.id)
      expect(ActionCable.server).to have_received(:broadcast).with(
        "post_thread_#{target_post.id}",
        hash_including(type: "new_reply", reply_to_post_id: target_post.id)
      )
    end

    context "when today_state is nil" do
      before { allow(ai_user).to receive(:today_state).and_return(nil) }

      it "does not create a reply" do
        expect {
          described_class.new.perform(ai_user.id, target_post.id)
        }.not_to change(AiPost, :count)
      end
    end

    context "when target post is not visible" do
      before { allow(target_post).to receive(:is_visible?).and_return(false) }

      it "does not create a reply" do
        expect {
          described_class.new.perform(ai_user.id, target_post.id)
        }.not_to change(AiPost, :count)
      end
    end

    context "when moderation detects a violation" do
      before do
        allow(Moderation::PostModerationService).to receive(:check)
          .and_return(double(violation: true, reason: "offensive content"))
      end

      it "does not create a reply" do
        expect {
          described_class.new.perform(ai_user.id, target_post.id)
        }.not_to change(AiPost, :count)
      end

      it "increments violation_count" do
        expect {
          described_class.new.perform(ai_user.id, target_post.id)
        }.to change { ai_user.reload.violation_count }.by(1)
      end
    end
  end
end
