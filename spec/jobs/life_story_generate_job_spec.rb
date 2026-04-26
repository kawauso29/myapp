require "rails_helper"

RSpec.describe LifeStoryGenerateJob, type: :job do
  describe "#perform" do
    let!(:active_ai)   { create(:ai_user, is_active: true) }
    let!(:inactive_ai) { create(:ai_user, is_active: false) }

    context "ライフイベントも記憶もないAI" do
      it "LLMを呼ばずにスキップする" do
        allow(LlmClient).to receive(:call)

        described_class.new.perform

        expect(LlmClient).not_to have_received(:call)
        expect(active_ai.ai_profile.reload.life_story).to be_nil
      end
    end

    context "ライフイベントがあるアクティブなAI" do
      before do
        AiLifeEvent.create!(
          ai_user: active_ai,
          event_type: :job_change,
          fired_at: Time.zone.local(2024, 3, 1)
        )
        active_ai.ai_profile.update!(name: "テストAI")
      end

      it "LLMを呼びライフストーリーをai_profileに保存する" do
        allow(LlmClient).to receive(:call).and_return("素晴らしい物語")

        described_class.new.perform

        profile = active_ai.ai_profile.reload
        expect(profile.life_story).to eq("素晴らしい物語")
        expect(profile.life_story_generated_at).to be_present
      end

      it "プロンプトに時系列出来事が含まれる" do
        captured_prompt = nil
        allow(LlmClient).to receive(:call) do |prompt, **|
          captured_prompt = prompt
          "物語テキスト"
        end

        described_class.new.perform

        expect(captured_prompt).to include("【時系列の出来事】")
        expect(captured_prompt).to include("2024年03月: job_change")
      end
    end

    context "長期記憶があるアクティブなAI" do
      before do
        AiLongTermMemory.create!(
          ai_user: active_ai,
          content: "素晴らしい出会いがあった",
          memory_type: :life_event,
          occurred_on: Date.new(2024, 5, 10)
        )
      end

      it "LLMを呼びライフストーリーをai_profileに保存する" do
        allow(LlmClient).to receive(:call).and_return("記憶に基づく物語")

        described_class.new.perform

        profile = active_ai.ai_profile.reload
        expect(profile.life_story).to eq("記憶に基づく物語")
      end

      it "プロンプトに記憶の内容が含まれる" do
        captured_prompt = nil
        allow(LlmClient).to receive(:call) do |prompt, **|
          captured_prompt = prompt
          "物語"
        end

        described_class.new.perform

        expect(captured_prompt).to include("素晴らしい出会いがあった")
      end
    end

    context "非アクティブなAI" do
      before do
        AiLifeEvent.create!(
          ai_user: inactive_ai,
          event_type: :marriage,
          fired_at: Time.zone.local(2024, 1, 1)
        )
      end

      it "非アクティブAIはスキップする" do
        allow(LlmClient).to receive(:call)

        described_class.new.perform

        expect(inactive_ai.ai_profile.reload.life_story).to be_nil
        expect(LlmClient).not_to have_received(:call)
      end
    end

    context "LLMがエラーを返した場合" do
      let!(:other_ai) { create(:ai_user, is_active: true) }

      before do
        AiLifeEvent.create!(ai_user: active_ai, event_type: :relocation, fired_at: Time.current)
        AiLifeEvent.create!(ai_user: other_ai, event_type: :promotion, fired_at: Time.current)
        active_ai.ai_profile.update!(name: "エラーAI")
        other_ai.ai_profile.update!(name: "成功AI")

        call_count = 0
        allow(LlmClient).to receive(:call) do |_prompt, **|
          call_count += 1
          raise StandardError, "LLM timeout" if call_count == 1

          "別のAIの物語"
        end
      end

      it "エラーが起きても他のAIの処理を継続する" do
        expect { described_class.new.perform }.not_to raise_error
        stories = [ active_ai.ai_profile.reload.life_story, other_ai.ai_profile.reload.life_story ]
        expect(stories).to include("別のAIの物語")
      end
    end
  end
end
