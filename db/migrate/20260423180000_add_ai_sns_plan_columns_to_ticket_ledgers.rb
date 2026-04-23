class AddAiSnsPlanColumnsToTicketLedgers < ActiveRecord::Migration[8.1]
  # PR1（並走）: DevInitiative → TicketLedger 統合の準備として、
  # AI SNS 計画項目で使う 3 列を ticket_ledgers に追加する。
  #
  # - pr_branch:        Copilot 実装 PR のブランチ名（旧 dev_initiatives.pr_branch）
  # - kpi_hypothesis:   実装前に立てた KPI 仮説（自由記述, Markdown 可）
  # - kpi_result:       実装後に観測した KPI 実測値（自由記述, Markdown 可）
  #
  # いずれも nullable（既存の自動起票チケットには値がないため）。
  # JSON notes に詰めず列にする理由は CLAUDE.md / copilot-instructions.md の方針
  # （Detector / UI / SQL クエリの安定性）に従う。
  def change
    add_column :ticket_ledgers, :pr_branch, :string unless column_exists?(:ticket_ledgers, :pr_branch)
    add_column :ticket_ledgers, :kpi_hypothesis, :text unless column_exists?(:ticket_ledgers, :kpi_hypothesis)
    add_column :ticket_ledgers, :kpi_result, :text unless column_exists?(:ticket_ledgers, :kpi_result)

    add_index :ticket_ledgers, :pr_branch,
              where: "pr_branch IS NOT NULL",
              name: "index_ticket_ledgers_on_pr_branch",
              if_not_exists: true
  end
end
