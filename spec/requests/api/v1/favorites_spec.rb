require "rails_helper"

RSpec.describe "Api::V1::Favorites", type: :request do
  def auth_token_for(user)
    post "/api/v1/auth/sign_in",
      params: { user: { email: user.email, password: user.password } },
      as: :json
    JSON.parse(response.body).dig("data", "token")
  end

  let(:user) { create(:user) }
  let(:ai_user) { create(:ai_user) }

  describe "POST /api/v1/ai_users/:ai_user_id/favorite" do
    context "認証あり" do
      it "お気に入りに追加し201を返す（未追加の場合）" do
        token = auth_token_for(user)

        expect {
          post "/api/v1/ai_users/#{ai_user.id}/favorite",
            headers: { "Authorization" => "Bearer #{token}" },
            as: :json
        }.to change(UserFavoriteAi, :count).by(1)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json["data"]["favorited"]).to be true
      end

      it "お気に入りを解除し200を返す（追加済みの場合）" do
        UserFavoriteAi.create!(user: user, ai_user: ai_user)
        token = auth_token_for(user)

        expect {
          post "/api/v1/ai_users/#{ai_user.id}/favorite",
            headers: { "Authorization" => "Bearer #{token}" },
            as: :json
        }.to change(UserFavoriteAi, :count).by(-1)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["data"]["favorited"]).to be false
      end

      it "存在しないai_userへは404を返す" do
        token = auth_token_for(user)

        post "/api/v1/ai_users/999999/favorite",
          headers: { "Authorization" => "Bearer #{token}" },
          as: :json

        expect(response).to have_http_status(:not_found)
      end
    end

    context "未認証" do
      it "401を返す" do
        post "/api/v1/ai_users/#{ai_user.id}/favorite", as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /api/v1/me/favorites" do
    context "認証あり" do
      it "お気に入りai_userの一覧を返す" do
        other_ai_users = create_list(:ai_user, 2)
        other_ai_users.each { |a| UserFavoriteAi.create!(user: user, ai_user: a) }
        token = auth_token_for(user)

        get "/api/v1/me/favorites",
          headers: { "Authorization" => "Bearer #{token}" }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["data"].length).to eq(2)
      end

      it "お気に入りがない場合は空配列を返す" do
        token = auth_token_for(user)

        get "/api/v1/me/favorites",
          headers: { "Authorization" => "Bearer #{token}" }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["data"]).to eq([])
      end

      it "他のユーザーのお気に入りは含まれない" do
        other_user = create(:user)
        UserFavoriteAi.create!(user: other_user, ai_user: ai_user)
        token = auth_token_for(user)

        get "/api/v1/me/favorites",
          headers: { "Authorization" => "Bearer #{token}" }

        json = JSON.parse(response.body)
        expect(json["data"]).to eq([])
      end
    end

    context "未認証" do
      it "401を返す" do
        get "/api/v1/me/favorites"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
