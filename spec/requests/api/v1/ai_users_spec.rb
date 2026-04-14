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
  let(:premium_user) { create(:user, plan: :premium) }

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
    allow(PlanEnforcer).to receive(:can_create_ai?).and_return(true)
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

    context "プラン上限に達している" do
      before do
        allow(PlanEnforcer).to receive(:can_create_ai?).and_return(false)
      end

      it "403を返す" do
        token = auth_token_for(user)

        post "/api/v1/ai_users",
          params: valid_profile_params,
          headers: { "Authorization" => "Bearer #{token}" },
          as: :json

        expect(response).to have_http_status(:forbidden)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("plan_limit_reached")
      end
    end

    context "プレミアムAI作成（premiumユーザー）" do
      before do
        allow(Moderation::ProfileModerationService).to receive(:check).and_return(
          Moderation::ProfileModerationService::Result.new(ok: true, reason: nil)
        )
        allow(AiCreation::DraftStore).to receive(:store).and_return("premium_draft_token")
      end

      it "プレビュー作成でき、プレミアム設定をdraftに含む" do
        token = auth_token_for(premium_user)

        post "/api/v1/ai_users",
          params: valid_profile_params.deep_merge(ai_user: { mode: "premium", premium_personality_template: "anime_style" }),
          headers: { "Authorization" => "Bearer #{token}" },
          as: :json

        expect(response).to have_http_status(:created)
        expect(AiCreation::DraftStore).to have_received(:store).with(
          premium_user.id,
          hash_including(
            is_premium_ai: true,
            premium_personality_template: "anime_style"
          )
        )
      end
    end

    context "プレミアムAI作成（freeユーザー）" do
      before do
        allow(Moderation::ProfileModerationService).to receive(:check).and_return(
          Moderation::ProfileModerationService::Result.new(ok: true, reason: nil)
        )
      end

      it "403を返す" do
        token = auth_token_for(user)

        post "/api/v1/ai_users",
          params: valid_profile_params.deep_merge(ai_user: { mode: "premium", premium_personality_template: "anime_style" }),
          headers: { "Authorization" => "Bearer #{token}" },
          as: :json

        expect(response).to have_http_status(:forbidden)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("premium_required")
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
        expect(json.dig("data", "voice_profile", "provider")).to be_present
        expect(json.dig("data", "voice_profile", "voice_key")).to be_present
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
        expect(captured_prompt).to include(memory_line)
        expect(captured_prompt).to include(event_line)
        expect(captured_prompt).to match(/#{Regexp.escape(memory_line)}.*#{Regexp.escape(event_line)}/m)
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

  describe "GET /api/v1/ai_users/:id/dm_peeks" do
    let(:ai_user) { create(:ai_user) }
    let(:partner_ai) { create(:ai_user) }

    before do
      create(:ai_relationship, ai_user: ai_user, target_ai_user: partner_ai, relationship_type: :close_friend, interaction_score: 88)
      create(:ai_relationship, ai_user: partner_ai, target_ai_user: ai_user, relationship_type: :close_friend, interaction_score: 86)
    end

    it "premiumユーザーは親密なAI同士のDMを閲覧できる" do
      thread = AiDmThread.create!(ai_user_a: ai_user, ai_user_b: partner_ai, status: :active, last_message_at: Time.current)
      AiDmMessage.create!(thread: thread, ai_user: ai_user, content: "最近どう？", dm_type: :chitchat)
      AiDmMessage.create!(thread: thread, ai_user: partner_ai, content: "いい感じ！", dm_type: :continuation)

      token = auth_token_for(premium_user)

      get "/api/v1/ai_users/#{ai_user.id}/dm_peeks",
        headers: { "Authorization" => "Bearer #{token}" }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"].size).to eq(1)
      expect(json["data"][0]["participants"].map { |p| p["id"] }).to contain_exactly(ai_user.id, partner_ai.id)
      expect(json["data"][0]["messages"].size).to eq(2)
      expect(json["data"][0]["messages"][1]["content"]).to eq("いい感じ！")
      expect(json["data"][0]["messages"][1].dig("voice", "provider")).to be_present
      expect(json["data"][0]["messages"][1].dig("voice", "voice_key")).to be_present
    end

    it "freeユーザーは403 premium_requiredを返す" do
      token = auth_token_for(user)

      get "/api/v1/ai_users/#{ai_user.id}/dm_peeks",
        headers: { "Authorization" => "Bearer #{token}" }

      expect(response).to have_http_status(:forbidden)
      json = JSON.parse(response.body)
      expect(json["error"]["code"]).to eq("premium_required")
    end
  end

  describe "GET /api/v1/ai_users/:id/today_voice" do
    let(:ai_user) { create(:ai_user, user: user) }

    it "最新投稿の音声再生用データを返す" do
      create(:ai_post, ai_user: ai_user, content: "おはよう、今日もがんばろう")

      get "/api/v1/ai_users/#{ai_user.id}/today_voice"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.dig("data", "text")).to eq("おはよう、今日もがんばろう")
      expect(json.dig("data", "source")).to eq("post")
      expect(json.dig("data", "voice_key")).to be_present
    end

    it "投稿がない場合は404を返す" do
      get "/api/v1/ai_users/#{ai_user.id}/today_voice"

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json.dig("error", "code")).to eq("not_found")
    end
  end

  describe "POST /api/v1/ai_users/:id/scout" do
    let(:creator) { create(:user, owner_score: 10) }
    let(:target_ai) { create(:ai_user, user: creator) }

    it "premiumユーザーは他人のAIをスカウトしてお気に入りに追加し、クリエイターへ還元する" do
      token = auth_token_for(premium_user)

      expect {
        post "/api/v1/ai_users/#{target_ai.id}/scout",
          headers: { "Authorization" => "Bearer #{token}" },
          as: :json
      }.to change(UserFavoriteAi, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json.dig("data", "scouted")).to be true
      expect(json.dig("data", "already_scouted")).to be false
      expect(json.dig("data", "creator_reward")).to eq(210)
      expect(creator.reload.owner_score).to eq(220)
      expect(UserFavoriteAi.exists?(user: premium_user, ai_user: target_ai)).to be true
    end

    it "同じAIを再スカウトすると重複作成せず成功を返す" do
      UserFavoriteAi.create!(user: premium_user, ai_user: target_ai)
      token = auth_token_for(premium_user)

      expect {
        post "/api/v1/ai_users/#{target_ai.id}/scout",
          headers: { "Authorization" => "Bearer #{token}" },
          as: :json
      }.not_to change(UserFavoriteAi, :count)

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.dig("data", "already_scouted")).to be true
      expect(creator.reload.owner_score).to eq(10)
    end

    it "freeユーザーは403 premium_requiredを返す" do
      token = auth_token_for(user)

      post "/api/v1/ai_users/#{target_ai.id}/scout",
        headers: { "Authorization" => "Bearer #{token}" },
        as: :json

      expect(response).to have_http_status(:forbidden)
      json = JSON.parse(response.body)
      expect(json.dig("error", "code")).to eq("premium_required")
    end

    it "自分のAIはスカウトできない" do
      own_ai = create(:ai_user, user: premium_user)
      token = auth_token_for(premium_user)

      post "/api/v1/ai_users/#{own_ai.id}/scout",
        headers: { "Authorization" => "Bearer #{token}" },
        as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json.dig("error", "code")).to eq("invalid_target")
    end
  end

  describe "POST /api/v1/ai_users/:id/gift" do
    let(:creator) { create(:user, owner_score: 50) }
    let(:target_ai) { create(:ai_user, user: creator) }

    before do
      create(:ai_daily_state, ai_user: target_ai, date: Date.current, post_motivation: 65)
    end

    it "premiumユーザーはお気に入りAIにギフトを送って特別投稿を生成できる" do
      UserFavoriteAi.create!(user: premium_user, ai_user: target_ai)
      token = auth_token_for(premium_user)

      expect {
        post "/api/v1/ai_users/#{target_ai.id}/gift",
          headers: { "Authorization" => "Bearer #{token}" },
          as: :json
      }.to change(AiPost, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json.dig("data", "gifted")).to be true
      expect(json.dig("data", "motivation_before")).to eq(65)
      expect(json.dig("data", "motivation_after")).to eq(85)
      expect(json.dig("data", "creator_reward")).to eq(60)
      expect(target_ai.ai_daily_states.find_by!(date: Date.current).post_motivation).to eq(85)
      expect(creator.reload.owner_score).to eq(110)
      post_record = AiPost.find(json.dig("data", "special_post_id"))
      expect(post_record.ai_user_id).to eq(target_ai.id)
      expect(post_record.content).to include("応援ギフトありがとう")
    end

    it "お気に入り登録していないAIにはギフトできない" do
      token = auth_token_for(premium_user)

      post "/api/v1/ai_users/#{target_ai.id}/gift",
        headers: { "Authorization" => "Bearer #{token}" },
        as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json.dig("error", "code")).to eq("favorite_required")
    end

    it "freeユーザーは403 premium_requiredを返す" do
      UserFavoriteAi.create!(user: user, ai_user: target_ai)
      token = auth_token_for(user)

      post "/api/v1/ai_users/#{target_ai.id}/gift",
        headers: { "Authorization" => "Bearer #{token}" },
        as: :json

      expect(response).to have_http_status(:forbidden)
      json = JSON.parse(response.body)
      expect(json.dig("error", "code")).to eq("premium_required")
    end

    it "自分のAIにはギフトできない" do
      own_ai = create(:ai_user, user: premium_user)
      UserFavoriteAi.create!(user: premium_user, ai_user: own_ai)
      token = auth_token_for(premium_user)

      post "/api/v1/ai_users/#{own_ai.id}/gift",
        headers: { "Authorization" => "Bearer #{token}" },
        as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json.dig("error", "code")).to eq("invalid_target")
    end

    it "投稿意欲は100を超えない" do
      UserFavoriteAi.create!(user: premium_user, ai_user: target_ai)
      target_ai.ai_daily_states.find_by!(date: Date.current).update!(post_motivation: 95)
      token = auth_token_for(premium_user)

      post "/api/v1/ai_users/#{target_ai.id}/gift",
        headers: { "Authorization" => "Bearer #{token}" },
        as: :json

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json.dig("data", "motivation_after")).to eq(100)
      expect(target_ai.ai_daily_states.find_by!(date: Date.current).post_motivation).to eq(100)
    end

    it "途中で失敗した場合はトランザクションがロールバックされる" do
      UserFavoriteAi.create!(user: premium_user, ai_user: target_ai)
      token = auth_token_for(premium_user)

      allow_any_instance_of(User).to receive(:increment!).and_raise(StandardError, "boom")

      expect {
        post "/api/v1/ai_users/#{target_ai.id}/gift",
          headers: { "Authorization" => "Bearer #{token}" },
          as: :json
      }.not_to change(AiPost, :count)

      expect(response).to have_http_status(:internal_server_error)
      expect(target_ai.ai_daily_states.find_by!(date: Date.current).post_motivation).to eq(65)
      expect(creator.reload.owner_score).to eq(50)
    end
  end

  describe "GET /api/v1/ai_users/:id/multiverse" do
    let(:ai_user) { create(:ai_user, user: user) }

    before do
      ai_user.ai_profile.update!(name: "分岐AI", age: 27, occupation: "デザイナー")
      create(:ai_post, ai_user: ai_user, content: "今日は静かな朝。")
      AiLifeEvent.create!(ai_user: ai_user, event_type: :promotion, fired_at: Time.current - 1.day)
    end

    it "認証なしで2つのタイムライン比較データを返す" do
      get "/api/v1/ai_users/#{ai_user.id}/multiverse"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.dig("data", "display_name")).to eq("分岐AI")
      expect(json.dig("data", "scenario", "event_key")).to eq("job_change")
      expect(json.dig("data", "timelines", "original")).to be_present
      expect(json.dig("data", "timelines", "multiverse")).to be_present
    end

    it "eventパラメータでif世界線の条件を切り替えられる" do
      get "/api/v1/ai_users/#{ai_user.id}/multiverse?event=marriage"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.dig("data", "scenario", "event_key")).to eq("marriage")
      expect(json.dig("data", "scenario", "event_label")).to eq("結婚")
      expect(json.dig("data", "timelines", "multiverse", 0, "text")).to include("もし")
    end
  end
end
