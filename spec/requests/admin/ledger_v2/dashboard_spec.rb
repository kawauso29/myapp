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

    context "連続 PASS 件数の表示（Phase G-0 観察）" do
      def create_passing_snapshot(offset_hours:)
        LedgerV2::HealthSnapshot.create!(
          period:                            :daily,
          measured_at:                       offset_hours.hours.ago,
          ticket_noise_rate:                 0.10,
          artifact_acceptance_rate:          0.80,
          runner_failure_rate:               0.05,
          unresolved_ticket_age_avg:         12.0,
          human_intervention_rate:           0.10,
          kpi_improvement_after_ticket_rate: 0.50,
          stop_trigger_count:                0,
          duplicate_prevented_count:         1,
          pending_review_count:              5,
          open_ticket_count:                 2
        )
      end

      it "snapshot が 0 件のとき 0 snapshot と表示する" do
        get "/admin/ledger_v2"

        expect(response.body).to include("連続 PASS")
      end

      it "7 件以上連続 PASS で Phase G-0 安定確認 OK バッジを表示する" do
        7.times { |i| create_passing_snapshot(offset_hours: i) }

        get "/admin/ledger_v2"

        expect(response.body).to include("Phase G-0 安定確認 OK")
      end

      it "1〜6 件連続 PASS で目標件数とともに表示する" do
        3.times { |i| create_passing_snapshot(offset_hours: i) }

        get "/admin/ledger_v2"

        expect(response.body).to include("連続 PASS")
        expect(response.body).to include("3")
      end
    end

    context "Monthly Runner セクション" do      it "Monthly Runner セクションを含む" do
        get "/admin/ledger_v2"

        expect(response.body).to include("Monthly Runner")
      end

      context "MonthlyRunner の Run が存在する場合" do
        let!(:monthly_run) do
          LedgerV2::Run.create!(
            runner_name:  "MonthlyRunner",
            status:       :success,
            trigger_type: :schedule,
            dry_run:      true,
            started_at:   1.hour.ago,
            finished_at:  30.minutes.ago,
            duration_ms:  3000
          )
        end

        it "MonthlyRunner の実行履歴を表示する" do
          get "/admin/ledger_v2"

          expect(response.body).to include("MonthlyRunner")
        end

        it "Monthly Run のステータスを表示する" do
          get "/admin/ledger_v2"

          expect(response.body).to include("success")
        end

        it "dry_run フラグを表示する" do
          get "/admin/ledger_v2"

          expect(response.body).to include("dry")
        end
      end

      context "monthly_review Artifact が存在する場合" do
        let!(:run) { LedgerV2::Run.create!(runner_name: "MonthlyRunner", trigger_type: :schedule, dry_run: true) }
        let!(:monthly_artifact) do
          LedgerV2::Artifact.create!(
            artifact_type: "monthly_review",
            title:         "月次 Ledger レビュー 2026-05",
            body:          "# 月次レビュー\n\n test",
            format:        "markdown",
            review_status: :pending,
            run:           run
          )
        end

        it "monthly_review Artifact のタイトルを表示する" do
          get "/admin/ledger_v2"

          expect(response.body).to include("月次 Ledger レビュー 2026-05")
        end

        it "Artifacts 一覧へのリンクを表示する" do
          get "/admin/ledger_v2"

          expect(response.body).to include("monthly_review")
        end
      end
    end
  end
end
