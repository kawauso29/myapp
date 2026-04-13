require "rails_helper"

RSpec.describe "Admin::Repository", type: :request do
  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_PASSWORD").and_return(nil)
  end

  describe "GET /admin" do
    it "リポジトリ全体管理とプロジェクト進捗が表示される" do
      get "/admin"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("リポジトリ全体の機能管理")
      expect(response.body).to include("self-hosted runner移行プロジェクト")
    end
  end
end
