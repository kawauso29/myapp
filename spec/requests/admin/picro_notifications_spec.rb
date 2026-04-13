require "rails_helper"

RSpec.describe "Admin::PicroNotifications", type: :request do
  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_PASSWORD").and_return(nil)
  end

  describe "GET /admin/picro_notifications" do
    it "Picro通知専用ページが表示される" do
      get "/admin/picro_notifications"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Picro通知専用ページ")
      expect(response.body).to include("Picro 送信履歴")
    end
  end
end
