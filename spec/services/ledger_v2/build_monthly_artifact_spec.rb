require "rails_helper"

RSpec.describe LedgerV2::BuildMonthlyArtifact, type: :service do
  let(:run) { LedgerV2::Run.create!(runner_name: "MonthlyRunner", trigger_type: :manual, dry_run: true) }

  def build_body(weekly_artifacts: [], active_tickets: [])
    described_class.call(run:, weekly_artifacts:, active_tickets:)
  end

  describe ".call" do
    it "月次レビュー draft のヘッダーを生成する" do
      body = build_body

      expect(body).to include("月次 Ledger レビュー draft")
      expect(body).to include("Run ID: #{run.id}")
      expect(body).to include("集約した Weekly Artifact 数: 0")
    end

    it "weekly_review Artifact を一覧化する" do
      artifact = LedgerV2::Artifact.create!(
        artifact_type: "weekly_review",
        title: "週次レビュー W18",
        body: "## 今週の異常\n投稿数が低下しました。",
        review_status: :pending,
        run:
      )

      body = build_body(weekly_artifacts: [artifact])

      expect(body).to include("Weekly Artifact 集約")
      expect(body).to include("週次レビュー W18")
      expect(body).to include("投稿数が低下しました")
    end

    it "high / critical の active Ticket を継続論点に含める" do
      ticket = LedgerV2::Ticket.create!(
        canonical_key: "monthly:critical:daily:2026-05-01",
        title: "重大な月次確認事項",
        status: :open,
        severity: :critical,
        review_status: :not_required,
        human_decision: :none
      )

      body = build_body(weekly_artifacts: [build(:ledger_v2_artifact_stub)], active_tickets: [ticket])

      expect(body).to include("継続論点")
      expect(body).to include("重大な月次確認事項")
    end

    it "30 日以上継続している active Ticket を長期化 Ticket に含める" do
      old_ticket = LedgerV2::Ticket.create!(
        canonical_key: "monthly:old:daily:2026-04-01",
        title: "長期化した課題",
        status: :deferred,
        severity: :medium,
        review_status: :not_required,
        human_decision: :none,
        created_at: 31.days.ago
      )

      body = build_body(active_tickets: [old_ticket])

      expect(body).to include("長期化 Ticket")
      expect(body).to include("長期化した課題")
    end

    it "自動 PR・自動マージを行わない注意を含める" do
      body = build_body

      expect(body).to include("自動 PR・自動マージは行いません")
      expect(body).to include("人間のレビューをお願いします")
    end
  end

  def build(attributes)
    case attributes
    when :ledger_v2_artifact_stub
      LedgerV2::Artifact.new(
        id: 999,
        artifact_type: "weekly_review",
        title: "stub weekly",
        body: "stub body",
        review_status: :pending,
        created_at: Time.current
      )
    end
  end
end
