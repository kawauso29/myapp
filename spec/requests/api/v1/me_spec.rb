require "rails_helper"

RSpec.describe "Api::V1::Me", type: :request do
  def auth_token_for(user)
    post "/api/v1/auth/sign_in",
      params: { user: { email: user.email, password: user.password } },
      as: :json
    JSON.parse(response.body).dig("data", "token")
  end

  describe "GET /api/v1/me" do
    context "認証あり" do
      let(:user) { create(:user, plan: "free", owner_score: 0) }

      it "200を返し自分の情報を含む" do
        token = auth_token_for(user)

        get "/api/v1/me", headers: { "Authorization" => "Bearer #{token}" }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        data = json["data"]
        expect(data["id"]).to eq(user.id)
        expect(data["email"]).to eq(user.email)
        expect(data["username"]).to eq(user.username)
      end

      it "planとowner_scoreを含む" do
        token = auth_token_for(user)

        get "/api/v1/me", headers: { "Authorization" => "Bearer #{token}" }

        json = JSON.parse(response.body)
        data = json["data"]
        expect(data["plan"]).to eq("free")
        expect(data["owner_score"]).to eq(0)
      end

      it "score_rankを含む" do
        token = auth_token_for(user)

        get "/api/v1/me", headers: { "Authorization" => "Bearer #{token}" }

        json = JSON.parse(response.body)
        expect(json["data"]["score_rank"]).to eq("bronze")
      end

      it "plan_limitsを含む" do
        token = auth_token_for(user)

        get "/api/v1/me", headers: { "Authorization" => "Bearer #{token}" }

        json = JSON.parse(response.body)
        expect(json["data"]["plan_limits"]).to be_present
        expect(json["data"]["plan_limits"]["max_ai_count"]).to eq(1)
      end

      it "ai_countを含む" do
        token = auth_token_for(user)

        get "/api/v1/me", headers: { "Authorization" => "Bearer #{token}" }

        json = JSON.parse(response.body)
        expect(json["data"]["ai_count"]).to eq(0)
      end

      it "created_atをISO8601形式で含む" do
        token = auth_token_for(user)

        get "/api/v1/me", headers: { "Authorization" => "Bearer #{token}" }

        json = JSON.parse(response.body)
        expect(json["data"]["created_at"]).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
      end

      context "owner_scoreが高いユーザー" do
        let(:user) { create(:user, owner_score: 10_000) }

        it "score_rankがgoldになる" do
          token = auth_token_for(user)

          get "/api/v1/me", headers: { "Authorization" => "Bearer #{token}" }

          json = JSON.parse(response.body)
          expect(json["data"]["score_rank"]).to eq("gold")
        end
      end

      context "premiumプランのユーザー" do
        let(:user) { create(:user, plan: "premium") }

        it "plan_limitsがpremium設定を返す" do
          token = auth_token_for(user)

          get "/api/v1/me", headers: { "Authorization" => "Bearer #{token}" }

          json = JSON.parse(response.body)
          expect(json["data"]["plan_limits"]["max_ai_count"]).to eq(10)
          expect(json["data"]["plan_limits"]["max_daily_actions"]).to eq("unlimited")
        end
      end
    end

    context "未認証" do
      it "401を返す" do
        get "/api/v1/me"

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("unauthorized")
      end
    end
  end
end
