require "rails_helper"

RSpec.describe LedgerV2::BuildQuarterlyArtifact, type: :service do
  let(:run) { LedgerV2::Run.create!(runner_name: "QuarterlyRunner", trigger_type: :manual, dry_run: true) }

  def build_body(monthly_artifacts: [], active_tickets: [])
    described_class.call(run:, monthly_artifacts:, active_tickets:)
  end

  describe ".call" do
    it "四半期レビュー draft のヘッダーを生成する" do
      body = build_body

      expect(body).to include("四半期 Ledger レビュー draft")
      expect(body).to include("Run ID: #{run.id}")
      expect(body).to include("集約した Monthly Artifact 数: 0")
    end

    it "monthly_review Artifact を一覧化する" do
      artifact = LedgerV2::Artifact.create!(
        artifact_type: "monthly_review",
        title: "月次レビュー M04",
        body: "## 今月の異常\n投稿数が低下しました。",
        review_status: :pending,
        run:
      )

      body = build_body(monthly_artifacts: [artifact])

      expect(body).to include("Monthly Artifact 集約")
      expect(body).to include("月次レビュー M04")
      expect(body).to include("投稿数が低下しました")
    end

    it "Monthly Artifact がない場合は集約なしを表示する" do
      body = build_body(monthly_artifacts: [])

      expect(body).to include("対象 monthly_review Artifact なし")
    end

    it "high / critical の active Ticket を継続論点に含める" do
      artifact = LedgerV2::Artifact.create!(
        artifact_type: "monthly_review",
        title: "stub monthly",
        body: "stub body",
        review_status: :pending,
        run:
      )
      ticket = LedgerV2::Ticket.create!(
        canonical_key:  "quarterly:critical:monthly:2026-05-01",
        title:          "重大な四半期確認事項",
        status:         :open,
        severity:       :critical,
        review_status:  :not_required,
        human_decision: :none
      )

      body = build_body(monthly_artifacts: [artifact], active_tickets: [ticket])

      expect(body).to include("継続論点")
      expect(body).to include("重大な四半期確認事項")
    end

    it "Monthly Artifact がない場合は継続論点の抽出対象なしを表示する" do
      ticket = LedgerV2::Ticket.create!(
        canonical_key:  "quarterly:critical:empty:2026-05-01",
        title:          "確認事項",
        status:         :open,
        severity:       :critical,
        review_status:  :not_required,
        human_decision: :none
      )

      body = build_body(monthly_artifacts: [], active_tickets: [ticket])

      expect(body).to include("Monthly Artifact がないため抽出対象なし")
    end

    it "90 日以上継続している active Ticket を長期化 Ticket に含める" do
      old_ticket = LedgerV2::Ticket.create!(
        canonical_key:  "quarterly:old:monthly:2026-01-01",
        title:          "長期化した課題",
        status:         :deferred,
        severity:       :medium,
        review_status:  :not_required,
        human_decision: :none,
        created_at:     91.days.ago
      )

      body = build_body(active_tickets: [old_ticket])

      expect(body).to include("長期化 Ticket")
      expect(body).to include("長期化した課題")
    end

    it "90 日未満の Ticket は長期化 Ticket に含めない" do
      recent_ticket = LedgerV2::Ticket.create!(
        canonical_key:  "quarterly:recent:monthly:2026-04-01",
        title:          "最近の課題",
        status:         :open,
        severity:       :low,
        review_status:  :not_required,
        human_decision: :none,
        created_at:     30.days.ago
      )

      body = build_body(active_tickets: [recent_ticket])

      expect(body).to include("90 日以上継続している active Ticket なし")
      expect(body).not_to include("最近の課題")
    end

    it "自動 PR・自動マージを行わない注意を含める" do
      body = build_body

      expect(body).to include("自動 PR・自動マージは行いません")
      expect(body).to include("人間のレビューをお願いします")
    end
  end
end
