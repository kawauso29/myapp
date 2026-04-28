require "rails_helper"

RSpec.describe LedgerV2::WeeklyRunner, type: :service do
  let(:run) { LedgerV2::Run.create!(runner_name: "WeeklyRunner", trigger_type: :schedule) }

  def call_runner(dry_run: false)
    described_class.call(run: run, dry_run: dry_run)
  end

  describe ".call" do
    context "open Ticket も MetricSnapshot もない場合" do
      it "RunnerResult を返す" do
        result = call_runner
        expect(result).to be_a(LedgerV2::RunExecutor::RunnerResult)
      end

      it "Artifact が 1 件作成される" do
        expect { call_runner }.to change(LedgerV2::Artifact, :count).by(1)
      end

      it "作成された Artifact の artifact_type が weekly_review" do
        call_runner
        artifact = LedgerV2::Artifact.last
        expect(artifact.artifact_type).to eq("weekly_review")
      end

      it "作成された Artifact の review_status が pending" do
        call_runner
        artifact = LedgerV2::Artifact.last
        expect(artifact.review_status).to eq("pending")
      end

      it "artifact_created Event が 1 件作成される" do
        expect { call_runner }.to change {
          LedgerV2::Event.where(event_type: "artifact_created").count
        }.by(1)
      end

      it "created_artifact_count が 1 になる" do
        result = call_runner
        expect(result.created_artifact_count).to eq(1)
      end

      it "created_event_count が 1 になる" do
        result = call_runner
        expect(result.created_event_count).to eq(1)
      end
    end

    context "open Ticket がある場合" do
      before do
        LedgerV2::Ticket.create!(
          canonical_key:  "test:low_ticket:daily:2026-01-01",
          title:          "低優先度テスト課題",
          status:         :open,
          severity:       :low,
          review_status:  :not_required,
          human_decision: :none
        )
        LedgerV2::Ticket.create!(
          canonical_key:  "test:high_ticket:daily:2026-01-01",
          title:          "高優先度テスト課題",
          status:         :open,
          severity:       :high,
          review_status:  :not_required,
          human_decision: :none
        )
      end

      it "Artifact 本文に open Ticket 一覧が含まれる" do
        call_runner
        artifact = LedgerV2::Artifact.last
        expect(artifact.body).to include("open Ticket 一覧")
        expect(artifact.body).to include("低優先度テスト課題")
        expect(artifact.body).to include("高優先度テスト課題")
      end

      it "Artifact 本文に改善候補（high severity）が含まれる" do
        call_runner
        artifact = LedgerV2::Artifact.last
        expect(artifact.body).to include("改善候補")
        expect(artifact.body).to include("高優先度テスト課題")
      end
    end

    context "dry_run: true の場合" do
      it "Artifact を作成しない" do
        expect { call_runner(dry_run: true) }.not_to change(LedgerV2::Artifact, :count)
      end

      it "Event を作成しない" do
        expect { call_runner(dry_run: true) }.not_to change(LedgerV2::Event, :count)
      end

      it "RunnerResult を返す" do
        result = call_runner(dry_run: true)
        expect(result).to be_a(LedgerV2::RunExecutor::RunnerResult)
      end

      it "created_artifact_count が 0 になる" do
        result = call_runner(dry_run: true)
        expect(result.created_artifact_count).to eq(0)
      end
    end

    context "直近 7 日間の MetricSnapshot がある場合" do
      before do
        LedgerV2::MetricSnapshot.create!(
          metric_name: "ai_sns_posts_count",
          value:       3.0,
          period:      :daily,
          measured_at: 2.days.ago.beginning_of_day,
          created_by_run: run
        )
      end

      it "Artifact 本文に MetricSnapshot の情報が含まれる" do
        call_runner
        artifact = LedgerV2::Artifact.last
        expect(artifact.body).to include("今週の異常")
        expect(artifact.body).to include("ai_sns_posts_count")
      end
    end
  end

  describe "Artifact の内容" do
    it "Artifact 本文にヘッダー情報が含まれる" do
      call_runner
      artifact = LedgerV2::Artifact.last
      expect(artifact.body).to include("週次 Ledger レビュー")
      expect(artifact.body).to include("Run ID: #{run.id}")
    end

    it "Artifact 本文にフッターが含まれる" do
      call_runner
      artifact = LedgerV2::Artifact.last
      expect(artifact.body).to include("人間のレビューをお願いします")
    end

    it "Artifact が Run と紐づいている" do
      call_runner
      artifact = LedgerV2::Artifact.last
      expect(artifact.run).to eq(run)
    end
  end
end
