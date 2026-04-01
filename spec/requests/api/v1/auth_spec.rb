require "rails_helper"

RSpec.describe "Api::V1::Auth", type: :request do
  describe "POST /api/v1/auth/sign_up" do
    let(:valid_params) do
      {
        user: {
          email: "newuser@example.com",
          username: "newuser",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    it "creates a new user and returns token" do
      expect {
        post "/api/v1/auth/sign_up", params: valid_params, as: :json
      }.to change(User, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["data"]["user"]["email"]).to eq("newuser@example.com")
      expect(json["data"]["user"]["username"]).to eq("newuser")
      expect(json["data"]["token"]).to be_present
    end

    it "returns the user data with expected fields" do
      post "/api/v1/auth/sign_up", params: valid_params, as: :json

      json = JSON.parse(response.body)
      user_data = json["data"]["user"]
      expect(user_data).to include("id", "email", "username", "plan", "owner_score", "created_at")
      expect(user_data["plan"]).to eq("free")
      expect(user_data["owner_score"]).to eq(0)
    end

    it "returns validation error for missing username" do
      invalid_params = valid_params.deep_merge(user: { username: "" })
      post "/api/v1/auth/sign_up", params: invalid_params, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["error"]["code"]).to eq("validation_error")
      expect(json["error"]["message"]).to be_present
    end

    it "returns validation error for duplicate email" do
      create(:user, email: "newuser@example.com")
      post "/api/v1/auth/sign_up", params: valid_params, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns validation error for password mismatch" do
      bad_params = valid_params.deep_merge(user: { password_confirmation: "wrong" })
      post "/api/v1/auth/sign_up", params: bad_params, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "POST /api/v1/auth/sign_in" do
    let!(:user) { create(:user, email: "login@example.com", password: "password123") }

    it "returns token and user data for valid credentials" do
      post "/api/v1/auth/sign_in",
        params: { user: { email: "login@example.com", password: "password123" } },
        as: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"]["user"]["email"]).to eq("login@example.com")
      expect(json["data"]["token"]).to be_present
    end

    it "returns 401 for invalid credentials" do
      post "/api/v1/auth/sign_in",
        params: { user: { email: "login@example.com", password: "wrongpassword" } },
        as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 for non-existent email" do
      post "/api/v1/auth/sign_in",
        params: { user: { email: "nobody@example.com", password: "password123" } },
        as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "protected endpoints require auth" do
    it "returns 401 for GET /api/v1/me without token" do
      get "/api/v1/me"

      expect(response).to have_http_status(:unauthorized)
    end

    it "allows access with valid JWT token" do
      user = create(:user)
      # Sign in to get a token
      post "/api/v1/auth/sign_in",
        params: { user: { email: user.email, password: user.password } },
        as: :json

      token = JSON.parse(response.body).dig("data", "token")

      get "/api/v1/me", headers: { "Authorization" => "Bearer #{token}" }

      expect(response).to have_http_status(:ok)
    end
  end
end
