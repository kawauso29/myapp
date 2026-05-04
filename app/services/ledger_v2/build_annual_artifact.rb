# LedgerV2::BuildAnnualArtifact — AnnualRunner 用の Artifact 本文（Markdown）を生成する。
#
# 責務:
# - 直近の quarterly_review Artifact を年次単位で集約する
# - 長期化している active Ticket を整理する
# - 人間レビューで確認すべき項目を明示する
#
# やらないこと:
# - Artifact を DB に保存しない（AnnualRunner が保存判断を担う）
# - 戦略・設定変更を確定しない
# - 自動 PR・自動マージを行わない
#
# 設計の正本: docs/projects/ledger-v2-migration.md §「Phase G-4: 次の Layer C 候補」
module LedgerV2
  class BuildAnnualArtifact
    ANNUAL_PERIOD_DAYS = 365
    EXCERPT_LENGTH = 180

    # @param run                  [LedgerV2::Run]
    # @param quarterly_artifacts  [Array<LedgerV2::Artifact>]
    # @param active_tickets       [Array<LedgerV2::Ticket>]
    # @return [String] Markdown 形式の本文
    def self.call(run:, quarterly_artifacts:, active_tickets: [])
      new(run:, quarterly_artifacts:, active_tickets:).call
    end

    def initialize(run:, quarterly_artifacts:, active_tickets:)
      @run                  = run
      @quarterly_artifacts  = quarterly_artifacts.to_a
      @active_tickets       = active_tickets.to_a
      @generated_at         = Time.current
    end

    def call
      [
        header_section,
        quarterly_artifacts_section,
        annual_themes_section,
        long_running_tickets_section,
        human_decision_section,
        footer_section
      ].join("\n\n")
    end

    private

    def header_section
      period_start = @generated_at - ANNUAL_PERIOD_DAYS.days
      "# 年次 Ledger レビュー draft\n\n" \
        "- 生成日時: #{@generated_at.strftime('%Y-%m-%d %H:%M')}\n" \
        "- 対象期間: #{period_start.strftime('%Y-%m-%d')} 〜 #{@generated_at.strftime('%Y-%m-%d')}\n" \
        "- Run ID: #{@run.id}\n" \
        "- 集約した Quarterly Artifact 数: #{@quarterly_artifacts.size}\n" \
        "- Active Ticket 数: #{@active_tickets.size}"
    end

    def quarterly_artifacts_section
      return "## Quarterly Artifact 集約\n\n（対象 quarterly_review Artifact なし）" if @quarterly_artifacts.empty?

      lines = ["## Quarterly Artifact 集約\n"]
      @quarterly_artifacts.each do |artifact|
        created_on = artifact.created_at&.strftime("%Y-%m-%d") || "unknown"
        lines << "- Artifact ##{artifact.id}: #{artifact.title}（#{created_on}, status: #{artifact.review_status}）"
        lines << "  - #{excerpt(artifact.body)}" if artifact.body.present?
      end
      lines.join("\n")
    end

    def annual_themes_section
      return "## 年間テーマ\n\n（Quarterly Artifact がないため抽出対象なし）" if @quarterly_artifacts.empty?

      high_or_critical = @active_tickets.select { |ticket| ticket.severity_high? || ticket.severity_critical? }
      lines = ["## 年間テーマ\n"]
      if high_or_critical.empty?
        lines << "（high / critical の active Ticket なし）"
      else
        high_or_critical.each do |ticket|
          lines << "- Ticket ##{ticket.id}: #{ticket.title}（severity: #{ticket.severity}, status: #{ticket.status}）"
        end
      end
      lines.join("\n")
    end

    def long_running_tickets_section
      threshold    = @generated_at - ANNUAL_PERIOD_DAYS.days
      long_running = @active_tickets.select { |ticket| ticket.created_at && ticket.created_at < threshold }
      lines = ["## 長期化 Ticket\n"]
      if long_running.empty?
        lines << "（365 日以上継続している active Ticket なし）"
      else
        long_running.each do |ticket|
          age_days = ((@generated_at - ticket.created_at) / 1.day).round
          lines << "- Ticket ##{ticket.id}: #{ticket.title}（#{age_days} 日経過, severity: #{ticket.severity}）"
        end
      end
      lines.join("\n")
    end

    def human_decision_section
      lines = ["## 人間レビューで確認すること\n"]
      lines << "- Quarterly Artifact の内容を年次観点で採用・保留・却下に整理する"
      lines << "- 長期化 Ticket を継続するか、分割するか、却下するか判断する"
      lines << "- この draft だけで戦略・設定・PR・マージを自動確定しない"
      lines.join("\n")
    end

    def footer_section
      "---\n\n" \
        "このドキュメントは LedgerV2::BuildAnnualArtifact が生成した年次 draft です。\n" \
        "確定・施策決定・自動 PR・自動マージは行いません。人間のレビューをお願いします。"
    end

    def excerpt(body)
      normalized = body.to_s.squish
      return normalized if normalized.length <= EXCERPT_LENGTH

      "#{normalized.first(EXCERPT_LENGTH)}..."
    end
  end
end
