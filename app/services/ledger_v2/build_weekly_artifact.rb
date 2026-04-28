# LedgerV2::BuildWeeklyArtifact — WeeklyRunner 用の Artifact 本文（Markdown）を生成する。
#
# 責務:
# - open / deferred Ticket を一覧化する
# - 直近 7 日の MetricSnapshot を集計して異常を洗い出す
# - 改善候補・carry_over候補・人間判断が必要な項目をまとめる
# - StopCondition 候補とノイズ候補を提示する
#
# やらないこと:
# - Artifact を DB に保存しない（WeeklyRunner が保存する）
# - 施策を確定しない
# - Ticket をクローズしない
# - 自動マージ・自動 PR を作らない
#
# 設計の正本: ledger_v2_detailed_design.txt §「LedgerV2::BuildWeeklyArtifact」
module LedgerV2
  class BuildWeeklyArtifact
    WEEKLY_PERIOD_DAYS = 7

    # @param run                     [LedgerV2::Run]
    # @param open_tickets            [ActiveRecord::Relation, Array<LedgerV2::Ticket>]
    # @param metric_snapshots        [Array<LedgerV2::MetricSnapshot>]
    # @param previous_weekly_artifacts [Array<LedgerV2::Artifact>]
    # @return [String] Markdown 形式の本文
    def self.call(run:, open_tickets:, metric_snapshots:, previous_weekly_artifacts: [])
      new(
        run:                       run,
        open_tickets:              open_tickets,
        metric_snapshots:          metric_snapshots,
        previous_weekly_artifacts: previous_weekly_artifacts
      ).call
    end

    def initialize(run:, open_tickets:, metric_snapshots:, previous_weekly_artifacts:)
      @run                       = run
      @open_tickets              = open_tickets.to_a
      @metric_snapshots          = metric_snapshots
      @previous_weekly_artifacts = previous_weekly_artifacts
      @generated_at              = Time.current
    end

    def call
      sections = []
      sections << header_section
      sections << anomaly_section
      sections << open_tickets_section
      sections << improvement_candidates_section
      sections << carry_over_section
      sections << human_decision_section
      sections << stop_condition_candidates_section
      sections << noise_candidates_section
      sections << footer_section
      sections.join("\n\n")
    end

    private

    def header_section
      period_start = @generated_at - WEEKLY_PERIOD_DAYS.days
      "# 週次 Ledger レビュー\n\n" \
        "- 生成日時: #{@generated_at.strftime('%Y-%m-%d %H:%M')}\n" \
        "- 対象期間: #{period_start.strftime('%Y-%m-%d')} 〜 #{@generated_at.strftime('%Y-%m-%d')}\n" \
        "- Run ID: #{@run.id}"
    end

    def anomaly_section
      daily_snaps = @metric_snapshots.select { |s| s.period == "daily" }
      if daily_snaps.empty?
        return "## 今週の異常\n\n（直近 7 日間の MetricSnapshot なし）"
      end

      lines = ["## 今週の異常\n"]
      grouped = daily_snaps.group_by(&:metric_name)
      grouped.each do |metric_name, snaps|
        values = snaps.filter_map(&:value)
        next if values.empty?

        latest = values.last
        avg    = values.sum.to_f / values.size
        lines << "- **#{metric_name}**: 最新値 #{latest}、直近#{values.size}日平均 #{avg.round(2)}"
      end
      lines.join("\n")
    end

    def open_tickets_section
      if @open_tickets.empty?
        return "## open Ticket 一覧\n\n（対象 Ticket なし）"
      end

      lines = ["## open Ticket 一覧\n", "| # | タイトル | severity | status |", "|---|---|---|---|"]
      @open_tickets.each do |t|
        lines << "| #{t.id} | #{t.title} | #{t.severity} | #{t.status} |"
      end
      lines.join("\n")
    end

    def improvement_candidates_section
      high_severity = @open_tickets.select { |t| %w[high critical].include?(t.severity) }
      lines = ["## 改善候補\n"]
      if high_severity.empty?
        lines << "（high / critical Ticket なし）"
      else
        high_severity.each do |t|
          lines << "- Ticket ##{t.id}: #{t.title}（severity: #{t.severity}）"
        end
      end
      lines.join("\n")
    end

    def carry_over_section
      old_tickets = @open_tickets.select do |t|
        t.created_at && t.created_at < @generated_at - WEEKLY_PERIOD_DAYS.days
      end
      lines = ["## carry_over 候補\n"]
      if old_tickets.empty?
        lines << "（前週以前からの未解決 Ticket なし）"
      else
        old_tickets.each do |t|
          age_days = ((@generated_at - t.created_at) / 1.day).round
          lines << "- Ticket ##{t.id}: #{t.title}（#{age_days} 日経過）"
        end
      end
      lines.join("\n")
    end

    def human_decision_section
      needs_decision = @open_tickets.select { |t| t.status_deferred? || %w[high critical].include?(t.severity) }
      lines = ["## 人間に判断してほしい項目\n"]
      if needs_decision.empty?
        lines << "（判断待ち Ticket なし）"
      else
        needs_decision.each do |t|
          lines << "- Ticket ##{t.id}: #{t.title}（status: #{t.status}、severity: #{t.severity}）"
        end
      end
      lines.join("\n")
    end

    def stop_condition_candidates_section
      lines = ["## StopCondition 候補\n"]
      critical_tickets = @open_tickets.select { |t| t.severity == "critical" }
      if critical_tickets.empty?
        lines << "（今週の critical Ticket なし → StopCondition 候補なし）"
      else
        lines << "以下の critical Ticket が継続する場合、StopCondition の設定を検討してください。\n"
        critical_tickets.each do |t|
          lines << "- Ticket ##{t.id}: #{t.title}"
        end
      end
      lines.join("\n")
    end

    def noise_candidates_section
      low_tickets = @open_tickets.select { |t| t.severity == "low" }
      lines = ["## ノイズ候補\n"]
      if low_tickets.empty?
        lines << "（low severity Ticket なし）"
      else
        lines << "以下は low severity Ticket です。繰り返し発生している場合は閾値見直しを検討してください。\n"
        low_tickets.each do |t|
          lines << "- Ticket ##{t.id}: #{t.title}"
        end
      end
      lines.join("\n")
    end

    def footer_section
      "---\n\n" \
        "このドキュメントは LedgerV2::WeeklyRunner が自動生成しました。\n" \
        "確定・施策決定・自動マージは行いません。人間のレビューをお願いします。"
    end
  end
end
