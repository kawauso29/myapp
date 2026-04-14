require "rails_helper"

RSpec.describe PostGenerateJob, type: :job do
  let(:ai_user)     { create(:ai_user) }
  let(:daily_state) { create(:ai_daily_state, ai_user: ai_user) }
  let(:motivation)  { { primary: :sharing, intensity: 3 } }
  let(:llm_response) do
    '{"content":"今日はいい天気だった。","tags":["日常"],"mood_expressed":"positive","emoji_used":false}'
  end

  before do
    allow(AiUser).to receive(:find).with(ai_user.id).and_return(ai_user)
    allow(ai_user).to receive(:today_state).and_return(daily_state)
    # LLM 呼び出しをモック
    allow_any_instance_of(described_class).to receive(:call_llm).and_return(llm_response)
    # モデレーションをパス
    allow(Moderation::PostModerationService).to receive(:check)
      .and_return(double(violation: false))
    # 通知・ブロードキャストをスタブ
    allow(ActionCable.server).to receive(:broadcast)
    allow(Notification::OwnerNotificationService).to receive(:notify_post)
    allow(SlackNotifierService).to receive(:notify)
    allow(AiPosts::ImageGenerator).to receive(:generate).and_return(nil)
  end

  describe "#perform" do
    it "creates a post for the AI user" do
      expect {
        described_class.new.perform(ai_user.id, motivation)
      }.to change(AiPost, :count).by(1)
    end

    it "increments the posts_count" do
      expect {
        described_class.new.perform(ai_user.id, motivation)
      }.to change { ai_user.reload.posts_count }.by(1)
    end

    it "broadcasts to global_timeline" do
      described_class.new.perform(ai_user.id, motivation)
      expect(ActionCable.server).to have_received(:broadcast).with("global_timeline", hash_including(type: "new_post"))
    end

    context "when today_state is nil" do
      before { allow(ai_user).to receive(:today_state).and_return(nil) }

      it "does not create a post" do
        expect {
          described_class.new.perform(ai_user.id, motivation)
        }.not_to change(AiPost, :count)
      end
    end

    context "when LLM response fails validation" do
      before do
        allow_any_instance_of(described_class).to receive(:call_llm).and_return("invalid json")
      end

      it "does not create a post" do
        expect {
          described_class.new.perform(ai_user.id, motivation)
        }.not_to change(AiPost, :count)
      end
    end

    context "when moderation detects a violation" do
      before do
        allow(Moderation::PostModerationService).to receive(:check)
          .and_return(double(violation: true, reason: "offensive content"))
      end

      it "does not create a post" do
        expect {
          described_class.new.perform(ai_user.id, motivation)
        }.not_to change(AiPost, :count)
      end

      it "increments violation_count" do
        expect {
          described_class.new.perform(ai_user.id, motivation)
        }.to change { ai_user.reload.violation_count }.by(1)
      end
    end

    context "when AI is premium" do
      let(:ai_user) { create(:ai_user, is_premium_ai: true, premium_personality_template: :anime_style) }
      let(:llm_response) do
        { content: "a" * 300, tags: [ "premium" ], mood_expressed: "positive", emoji_used: false }.to_json
      end

      before do
        allow(AiPosts::ImageGenerator).to receive(:generate).and_return({
          prompt: "sample prompt",
          url: "https://example.com/sample.png"
        })
      end

      it "allows long posts and attaches image metadata" do
        described_class.new.perform(ai_user.id, motivation)

        post = AiPost.order(:id).last
        expect(post.content.length).to eq(300)
        expect(post.image_url).to be_present
        expect(post.image_prompt).to be_present
      end
    end

    context "when image generation is skipped by daily limit" do
      let(:ai_user) { create(:ai_user, is_premium_ai: true, premium_personality_template: :anime_style) }

      before do
        allow(AiPosts::ImageGenerator).to receive(:generate).and_return(nil)
      end

      it "creates a text-only post" do
        described_class.new.perform(ai_user.id, motivation)

        post = AiPost.order(:id).last
        expect(post.image_url).to be_nil
        expect(post.image_prompt).to be_nil
      end
    end
  end
end
