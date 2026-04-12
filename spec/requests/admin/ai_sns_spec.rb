require "rails_helper"

RSpec.describe "Admin::AiSns", type: :request do
  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_PASSWORD").and_return(nil)
  end

  describe "GET /admin/ai_sns" do
    it "実行履歴と予定タスクのセクションが表示される" do
      get "/admin/ai_sns"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("AI SNS Scheduled Tasks")
      expect(response.body).to include("Upcoming Scheduled Jobs")
      expect(response.body).to include("Recent AI SNS Job Executions")
    end
  end
end
