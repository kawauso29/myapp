require "rails_helper"

RSpec.describe "Api::V1::AiUsers", type: :request do
  # Helper: sign in and return JWT token
  def auth_token_for(user)
    post "/api/v1/auth/sign_in",
      params: { user: { email: user.email, password: user.password } },
      as: :json
    JSON.parse(response.body).dig("data", "token")
  end

  let(:user) { create(:user) }

  let(:valid_profile_params) do
    {
      ai_user: {
        mode: "simple",
        profile: {
          name: "テスト子",
          age: 25,
          occupation: "エンジニア",
          gender: "female",
          personality_note: "明るくて社交的な人"
        }
      }
    }
  end

  let(:personality_attrs) do
    {
      sociability: :high,
      post_frequency: :normal,
      active_time_peak: :normal,
      need_for_approval: :normal,
      emotional_range: :normal,
      risk_tolerance: :normal,
      self_expression: :normal,
      drinking_frequency: :low,
      self_esteem: :normal,
      empathy: :normal,
      jealousy: :low,
      curiosity: :normal,
      follow_philosophy: :casual,
      primary_purpose: :self_recorder,
      secondary_purpose: nil
    }
  end

  let(:profile_attrs) do
    {
      name: "テスト子",
      age: 25,
      occupation: "エンジニア",
      gender: "female",
      occupation_type: "employed",
      location: "Tokyo",
      bio: "明るい人",
      life_stage: "single",
      family_structure: "alone",
      relationship_status: "single",
      hobbies: [],
      personality_note: "明るくて社交的な人"
    }
  end

  before do
    allow(AiCreation::PersonalityGenerator).to receive(:generate).and_return(personality_attrs)
    allow(AiCreation::ProfileBuilder).to receive(:build).and_return(profile_attrs)
    allow(AiCreation::InterestTagExtractor).to receive(:extract)
  end

  describe "POST /api/v1/ai_users" do
    context "プレビュー生成（モデレーションOK）" do
      before do
        allow(Moderation::ProfileModerationService).to receive(:check).and_return(
          Moderation::ProfileModerationService::Result.new(ok: true, reason: nil)
        )
        allow(AiCreation::DraftStore).to receive(:store).and_return("dummy_token_abc123")
      end

      it "201を返しpreviewとdraft_tokenを含む" do
        token = auth_token_for(user)

        post "/api/v1/ai_users",
          params: valid_profile_params,
          headers: { "Authorization" => "Bearer #{token}" },
          as: :json

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json["data"]["draft_token"]).to eq("dummy_token_abc123")
        expect(json["data"]["preview"]).to be_present
        expect(json["data"]["preview"]["profile"]).to be_present
      end

      it "PersonalityGeneratorとProfileBuilderを呼び出す" do
        token = auth_token_for(user)

        post "/api/v1/ai_users",
          params: valid_profile_params,
          headers: { "Authorization" => "Bearer #{token}" },
          as: :json

        expect(AiCreation::PersonalityGenerator).to have_received(:generate)
        expect(AiCreation::ProfileBuilder).to have_received(:build)
      end
    end

    context "モデレーションNG" do
      before do
        allow(Moderation::ProfileModerationService).to receive(:check).and_return(
          Moderation::ProfileModerationService::Result.new(ok: false, reason: "不適切な表現が含まれています")
        )
      end

      it "400を返しvalidation_errorコードを含む" do
        token = auth_token_for(user)

        post "/api/v1/ai_users",
          params: valid_profile_params,
          headers: { "Authorization" => "Bearer #{token}" },
          as: :json

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("validation_error")
        expect(json["error"]["message"]).to be_present
      end
    end

    context "未認証" do
      it "401を返す" do
        post "/api/v1/ai_users", params: valid_profile_params, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/v1/ai_users/confirm" do
    context "有効なdraft_token" do
      let(:draft_data) do
        {
          profile: profile_attrs,
          personality: personality_attrs,
          mode: "simple"
        }
      end

      before do
        allow(AiCreation::DraftStore).to receive(:consume).and_return(draft_data)
      end

      it "201を返しai_userを作成する" do
        token = auth_token_for(user)

        expect {
          post "/api/v1/ai_users/confirm",
            params: { draft_token: "valid_token" },
            headers: { "Authorization" => "Bearer #{token}" },
            as: :json
        }.to change(AiUser, :count).by(1)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json["data"]["ai_user"]).to be_present
        expect(json["data"]["ai_user"]["username"]).to be_present
      end
    end

    context "無効または期限切れのdraft_token" do
      before do
        allow(AiCreation::DraftStore).to receive(:consume).and_return(nil)
      end

      it "404を返す" do
        token = auth_token_for(user)

        post "/api/v1/ai_users/confirm",
          params: { draft_token: "expired_token" },
          headers: { "Authorization" => "Bearer #{token}" },
          as: :json

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("not_found")
      end
    end

    context "未認証" do
      it "401を返す" do
        post "/api/v1/ai_users/confirm", params: { draft_token: "token" }, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /api/v1/ai_users/:id" do
    let(:ai_user) { create(:ai_user, user: user) }

    context "認証なし" do
      it "200を返しai_userの情報を含む" do
        get "/api/v1/ai_users/#{ai_user.id}"

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["data"]["id"]).to eq(ai_user.id)
        expect(json["data"]["username"]).to eq(ai_user.username)
      end
    end

    context "認証あり" do
      it "200を返す" do
        token = auth_token_for(user)

        get "/api/v1/ai_users/#{ai_user.id}",
          headers: { "Authorization" => "Bearer #{token}" }

        expect(response).to have_http_status(:ok)
      end
    end

    context "存在しないID" do
      it "404を返す" do
        get "/api/v1/ai_users/999999"

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /api/v1/ai_users/:id/life_story" do
    let(:ai_user) { create(:ai_user, user: user) }

    context "ライフイベントと記憶がある場合" do
      it "時系列集約したプロンプトでLLMを呼び、サマリーを返す" do
        ai_user.ai_profile.update!(name: "物語AI")
        AiLongTermMemory.create!(
          ai_user: ai_user,
          content: "小さな挑戦を始めた",
          memory_type: :life_event,
          occurred_on: Date.new(2024, 1, 1)
        )
        AiLifeEvent.create!(
          ai_user: ai_user,
          event_type: :job_change,
          fired_at: Time.zone.local(2024, 2, 1)
        )

        captured_prompt = nil
        allow(LlmClient).to receive(:call) do |prompt, **|
          captured_prompt = prompt
          "温かいライフストーリー"
        end

        get "/api/v1/ai_users/#{ai_user.id}/life_story"

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["data"]["display_name"]).to eq("物語AI")
        expect(json["data"]["story"]).to eq("温かいライフストーリー")
        expect(json["data"]["life_event_count"]).to eq(1)
        expect(json["data"]["memory_count"]).to eq(1)
        expect(captured_prompt).to include("【時系列の出来事】")

        memory_line = "2024年01月: 小さな挑戦を始めた"
        event_line = "2024年02月: job_change"
        expect(captured_prompt.index(memory_line)).to be < captured_prompt.index(event_line)
      end
    end

    context "データがない場合" do
      it "LLMを呼ばずにデフォルトのメッセージを返す" do
        allow(LlmClient).to receive(:call)

        get "/api/v1/ai_users/#{ai_user.id}/life_story"

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["data"]["story"]).to include("まだ歩み始めたばかり")
        expect(LlmClient).not_to have_received(:call)
      end
    end
  end
end
