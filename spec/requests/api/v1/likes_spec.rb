require "rails_helper"

RSpec.describe "Api::V1::Likes", type: :request do
  def auth_token_for(user)
    post "/api/v1/auth/sign_in",
      params: { user: { email: user.email, password: user.password } },
      as: :json
    JSON.parse(response.body).dig("data", "token")
  end

  let(:user) { create(:user) }
  let(:ai_user) { create(:ai_user) }
  let(:post_record) { create(:ai_post, ai_user: ai_user) }

  describe "POST /api/v1/posts/:post_id/likes" do
    context "認証あり" do
      it "いいねを作成し201を返す" do
        token = auth_token_for(user)

        expect {
          post "/api/v1/posts/#{post_record.id}/likes",
            headers: { "Authorization" => "Bearer #{token}" },
            as: :json
        }.to change(UserAiLike, :count).by(1)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json["data"]["liked"]).to be true
      end

      it "同じ投稿に2回いいねしても重複しない" do
        token = auth_token_for(user)

        post "/api/v1/posts/#{post_record.id}/likes",
          headers: { "Authorization" => "Bearer #{token}" },
          as: :json

        expect {
          post "/api/v1/posts/#{post_record.id}/likes",
            headers: { "Authorization" => "Bearer #{token}" },
            as: :json
        }.not_to change(UserAiLike, :count)

        expect(response).to have_http_status(:created)
      end

      it "いいね後にlikes_countが増加する" do
        token = auth_token_for(user)
        initial_count = post_record.likes_count

        post "/api/v1/posts/#{post_record.id}/likes",
          headers: { "Authorization" => "Bearer #{token}" },
          as: :json

        expect(post_record.reload.likes_count).to eq(initial_count + 1)
      end

      it "存在しない投稿へのいいねは404を返す" do
        token = auth_token_for(user)

        post "/api/v1/posts/999999/likes",
          headers: { "Authorization" => "Bearer #{token}" },
          as: :json

        expect(response).to have_http_status(:not_found)
      end
    end

    context "未認証" do
      it "401を返す" do
        post "/api/v1/posts/#{post_record.id}/likes", as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "DELETE /api/v1/posts/:post_id/likes" do
    context "認証あり、いいね済み" do
      before do
        UserAiLike.create!(user: user, ai_post: post_record)
        post_record.update!(likes_count: 1, user_likes_count: 1)
      end

      it "いいねを削除し200を返す" do
        token = auth_token_for(user)

        expect {
          delete "/api/v1/posts/#{post_record.id}/likes",
            headers: { "Authorization" => "Bearer #{token}" },
            as: :json
        }.to change(UserAiLike, :count).by(-1)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["data"]["liked"]).to be false
      end

      it "いいね解除後にlikes_countが減少する" do
        token = auth_token_for(user)

        delete "/api/v1/posts/#{post_record.id}/likes",
          headers: { "Authorization" => "Bearer #{token}" },
          as: :json

        expect(post_record.reload.likes_count).to eq(0)
      end
    end

    context "認証あり、いいね未済み" do
      it "エラーなく200を返す" do
        token = auth_token_for(user)

        delete "/api/v1/posts/#{post_record.id}/likes",
          headers: { "Authorization" => "Bearer #{token}" },
          as: :json

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["data"]["liked"]).to be false
      end
    end

    context "未認証" do
      it "401を返す" do
        delete "/api/v1/posts/#{post_record.id}/likes", as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
