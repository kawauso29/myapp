require "rails_helper"

RSpec.describe "Admin::LedgerV2::Dashboard", type: :request do
  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_PASSWORD").and_return(nil)
  end

  describe "GET /admin/ledger_v2" do
    context "Run も Ticket も Artifact もない場合" do
      it "200 OK を返す" do
        get "/admin/ledger_v2"

        expect(response).to have_http_status(:ok)
      end

      it "LedgerV2 Dashboard の見出しを含む" do
        get "/admin/ledger_v2"

        expect(response.body).to include("LedgerV2")
      end

      it "直近 Run セクションを含む" do
        get "/admin/ledger_v2"

        expect(response.body).to include("直近 Run")
      end

      it "open Ticket セクションを含む" do
        get "/admin/ledger_v2"

        expect(response.body).to include("open Ticket")
      end

      it "レビュー待ち Artifact セクションを含む" do
        get "/admin/ledger_v2"

        expect(response.body).to include("レビュー待ち Artifact")
      end
    end

    context "Run が存在する場合" do
      let!(:success_run) do
        LedgerV2::Run.create!(
          runner_name:  "DailyRunner",
          status:       :success,
          trigger_type: :schedule,
          started_at:   1.hour.ago,
          finished_at:  30.minutes.ago,
          duration_ms:  1500
        )
      end
      let!(:failed_run) do
        LedgerV2::Run.create!(
          runner_name:   "WeeklyRunner",
          status:        :failed,
          trigger_type:  :schedule,
          started_at:    2.hours.ago,
          error_class:   "RuntimeError",
          error_message: "something went wrong"
        )
      end

      it "runner_name を表示する" do
        get "/admin/ledger_v2"

        expect(response.body).to include("DailyRunner")
        expect(response.body).to include("WeeklyRunner")
      end

      it "status を表示する" do
        get "/admin/ledger_v2"

        expect(response.body).to include("success")
        expect(response.body).to include("failed")
      end

      it "失敗 Run のエラーメッセージを表示する" do
        get "/admin/ledger_v2"

        expect(response.body).to include("something went wrong")
      end
    end

    context "open Ticket が存在する場合" do
      let!(:ticket) do
        LedgerV2::Ticket.create!(
          canonical_key:  "test:high_posts:daily:2026-01-01",
          title:          "投稿数異常",
          status:         :open,
          severity:       :high,
          review_status:  :not_required,
          human_decision: :none,
          metric_name:    "ai_sns_posts_count"
        )
      end

      it "Ticket タイトルを表示する" do
        get "/admin/ledger_v2"

        expect(response.body).to include("投稿数異常")
      end
    end

    context "pending Artifact が存在する場合" do
      let!(:run) { LedgerV2::Run.create!(runner_name: "WeeklyRunner", trigger_type: :schedule) }
      let!(:artifact) do
        LedgerV2::Artifact.create!(
          artifact_type: "weekly_review",
          title:         "週次レビュー 2026-01-01",
          body:          "test body",
          format:        "markdown",
          review_status: :pending,
          run:           run
        )
      end

      it "Artifact タイトルを表示する" do
        get "/admin/ledger_v2"

        expect(response.body).to include("週次レビュー 2026-01-01")
      end
    end

    context "active StopCondition が存在する場合" do
      let!(:stop) do
        LedgerV2::StopCondition.create!(
          target_type: "runner",
          target_name: "WeeklyRunner",
          reason:      "critical error detected",
          severity:    "critical",
          active:      true,
          created_by:  "test"
        )
      end

      it "StopCondition の警告バナーを表示する" do
        get "/admin/ledger_v2"

        expect(response.body).to include("Active StopCondition")
        expect(response.body).to include("critical error detected")
      end
    end
  end
end
