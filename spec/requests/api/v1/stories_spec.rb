require "rails_helper"

RSpec.describe "Api::V1::Stories", type: :request do
  def auth_token_for(user)
    post "/api/v1/auth/sign_in",
      params: { user: { email: user.email, password: user.password } },
      as: :json
    JSON.parse(response.body).dig("data", "token")
  end

  let(:user) { create(:user) }
  let(:ai_user) { create(:ai_user) }
  let(:story_post) { create(:ai_post, :story, ai_user: ai_user) }

  describe "GET /api/v1/stories" do
    it "24時間以内のストーリーのみ返す" do
      latest = create(:ai_post, :story, ai_user: ai_user, created_at: 10.minutes.ago)
      create(:ai_post, :story, ai_user: ai_user, created_at: 1.hour.ago)
      create(:ai_post, :story, story_expires_at: 5.minutes.ago)
      create(:ai_post, ai_user: ai_user, is_story: false)

      get "/api/v1/stories"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"].size).to eq(1)
      expect(json["data"].first["id"]).to eq(latest.id)
    end

    it "ログイン時は自分のリアクションを返す" do
      create(:ai_story_reaction, ai_post: story_post, user: user, emoji: "🔥")
      token = auth_token_for(user)

      get "/api/v1/stories", headers: { "Authorization" => "Bearer #{token}" }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.dig("data", 0, "my_reaction")).to eq("🔥")
      expect(json.dig("data", 0, "reactions", "🔥")).to eq(1)
    end
  end

  describe "POST /api/v1/stories/:id/reaction" do
    it "未認証は401を返す" do
      post "/api/v1/stories/#{story_post.id}/reaction", params: { emoji: "🔥" }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it "リアクションを作成する" do
      token = auth_token_for(user)

      expect {
        post "/api/v1/stories/#{story_post.id}/reaction",
          params: { emoji: "🔥" },
          headers: { "Authorization" => "Bearer #{token}" },
          as: :json
      }.to change(AiStoryReaction, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).dig("data", "emoji")).to eq("🔥")
    end

    it "既存リアクションは上書きする" do
      create(:ai_story_reaction, ai_post: story_post, user: user, emoji: "🔥")
      token = auth_token_for(user)

      expect {
        post "/api/v1/stories/#{story_post.id}/reaction",
          params: { emoji: "👏" },
          headers: { "Authorization" => "Bearer #{token}" },
          as: :json
      }.not_to change(AiStoryReaction, :count)

      expect(response).to have_http_status(:ok)
      expect(AiStoryReaction.find_by(user: user, ai_post: story_post)&.emoji).to eq("👏")
    end
  end

  describe "DELETE /api/v1/stories/:id/reaction" do
    it "リアクションを削除する" do
      create(:ai_story_reaction, ai_post: story_post, user: user, emoji: "🔥")
      token = auth_token_for(user)

      expect {
        delete "/api/v1/stories/#{story_post.id}/reaction",
          headers: { "Authorization" => "Bearer #{token}" },
          as: :json
      }.to change(AiStoryReaction, :count).by(-1)

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).dig("data", "reacted")).to be(false)
    end
  end
end
