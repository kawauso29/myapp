require "rails_helper"

RSpec.describe LedgerV2::BuildAnnualArtifact, type: :service do
  let(:run) { LedgerV2::Run.create!(runner_name: "AnnualRunner", trigger_type: :manual, dry_run: true) }

  def build_body(quarterly_artifacts: [], active_tickets: [])
    described_class.call(run:, quarterly_artifacts:, active_tickets:)
  end

  describe ".call" do
    it "年次レビュー draft のヘッダーを生成する" do
      body = build_body

      expect(body).to include("年次 Ledger レビュー draft")
      expect(body).to include("Run ID: #{run.id}")
      expect(body).to include("集約した Quarterly Artifact 数: 0")
    end

    it "quarterly_review Artifact を一覧化する" do
      artifact = LedgerV2::Artifact.create!(
        artifact_type: "quarterly_review",
        title: "四半期レビュー Q1",
        body: "## 今期の異常\n投稿数が低下しました。",
        review_status: :pending,
        run:
      )

      body = build_body(quarterly_artifacts: [artifact])

      expect(body).to include("Quarterly Artifact 集約")
      expect(body).to include("四半期レビュー Q1")
      expect(body).to include("投稿数が低下しました")
    end

    it "Quarterly Artifact がない場合は集約なしを表示する" do
      body = build_body(quarterly_artifacts: [])

      expect(body).to include("対象 quarterly_review Artifact なし")
    end

    it "high / critical の active Ticket を年間テーマに含める" do
      artifact = LedgerV2::Artifact.create!(
        artifact_type: "quarterly_review",
        title: "stub quarterly",
        body: "stub body",
        review_status: :pending,
        run:
      )
      ticket = LedgerV2::Ticket.create!(
        canonical_key:  "annual:critical:quarterly:2026-05-01",
        title:          "重大な年次確認事項",
        status:         :open,
        severity:       :critical,
        review_status:  :not_required,
        human_decision: :none
      )

      body = build_body(quarterly_artifacts: [artifact], active_tickets: [ticket])

      expect(body).to include("年間テーマ")
      expect(body).to include("重大な年次確認事項")
    end

    it "Quarterly Artifact がない場合は年間テーマの抽出対象なしを表示する" do
      ticket = LedgerV2::Ticket.create!(
        canonical_key:  "annual:critical:empty:2026-05-01",
        title:          "確認事項",
        status:         :open,
        severity:       :critical,
        review_status:  :not_required,
        human_decision: :none
      )

      body = build_body(quarterly_artifacts: [], active_tickets: [ticket])

      expect(body).to include("Quarterly Artifact がないため抽出対象なし")
    end

    it "365 日以上継続している active Ticket を長期化 Ticket に含める" do
      old_ticket = LedgerV2::Ticket.create!(
        canonical_key:  "annual:old:quarterly:2025-01-01",
        title:          "長期化した年次課題",
        status:         :deferred,
        severity:       :medium,
        review_status:  :not_required,
        human_decision: :none,
        created_at:     366.days.ago
      )

      body = build_body(active_tickets: [old_ticket])

      expect(body).to include("長期化 Ticket")
      expect(body).to include("長期化した年次課題")
    end

    it "365 日未満の Ticket は長期化 Ticket に含めない" do
      recent_ticket = LedgerV2::Ticket.create!(
        canonical_key:  "annual:recent:quarterly:2026-01-01",
        title:          "最近の課題",
        status:         :open,
        severity:       :low,
        review_status:  :not_required,
        human_decision: :none,
        created_at:     90.days.ago
      )

      body = build_body(active_tickets: [recent_ticket])

      expect(body).to include("365 日以上継続している active Ticket なし")
      expect(body).not_to include("最近の課題")
    end

    it "自動 PR・自動マージを行わない注意を含める" do
      body = build_body

      expect(body).to include("自動 PR・自動マージは行いません")
      expect(body).to include("人間のレビューをお願いします")
    end
  end
end
