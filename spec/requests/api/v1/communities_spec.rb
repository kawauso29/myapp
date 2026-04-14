# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Communities", type: :request do
  def auth_token_for(user)
    post "/api/v1/auth/sign_in",
      params: { user: { email: user.email, password: user.password } },
      as: :json
    JSON.parse(response.body).dig("data", "token")
  end

  let(:user) { create(:user) }
  let!(:community) do
    AiCommunity.create!(
      name: "料理好きサークル",
      description: "料理に興味があるAIたちのグループ",
      category: "料理",
      emoji: "🍳"
    )
  end

  let!(:ai_user1) { create(:ai_user) }
  let!(:ai_user2) { create(:ai_user) }

  before do
    AiCommunityMembership.create!(ai_community: community, ai_user: ai_user1)
    AiCommunityMembership.create!(ai_community: community, ai_user: ai_user2)
  end

  describe "GET /api/v1/communities" do
    it "returns a list of communities" do
      get "/api/v1/communities", as: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      data = json["data"]
      expect(data).to be_an(Array)
      expect(data.first["name"]).to eq("料理好きサークル")
      expect(data.first["members_count"]).to eq(2)
      expect(data.first["emoji"]).to eq("🍳")
    end
  end

  describe "GET /api/v1/communities/:id" do
    it "returns community details" do
      get "/api/v1/communities/#{community.id}", as: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"]["name"]).to eq("料理好きサークル")
      expect(json["data"]["is_followed"]).to eq(false)
    end
  end

  describe "GET /api/v1/communities/:id/members" do
    it "returns community members" do
      get "/api/v1/communities/#{community.id}/members", as: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      data = json["data"]
      expect(data).to be_an(Array)
      expect(data.size).to eq(2)
    end
  end

  describe "POST /api/v1/communities/:id/follow" do
    it "follows and unfollows a community" do
      token = auth_token_for(user)
      headers = { "Authorization" => "Bearer #{token}" }

      # Follow
      post "/api/v1/communities/#{community.id}/follow", headers: headers, as: :json
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"]["followed"]).to eq(true)

      # Verify follow exists
      expect(user.user_community_follows.where(ai_community: community).exists?).to be(true)

      # Unfollow
      post "/api/v1/communities/#{community.id}/follow", headers: headers, as: :json
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"]["followed"]).to eq(false)

      # Verify follow removed
      expect(user.user_community_follows.where(ai_community: community).exists?).to be(false)
    end

    it "requires authentication" do
      post "/api/v1/communities/#{community.id}/follow", as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
