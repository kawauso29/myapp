namespace :github_issues do
  # 不適切な @copilot コメント付き Issue を一括クローズする。
  # 対象: quarterly_review / annual_plan のサマリーチケット、operations "default ticket" の重複分。
  # 実行: bin/rails github_issues:close_stale
  #
  # NOTE: これは 2026-04 の一時的なクリーンアップタスクです。実行後は削除してください。
  # 実行済みかどうかは GitHub Issue の closed 状態で確認できます（#311〜#317, #319〜#321）。
  desc "不適切な @copilot メンション付き Issue（quarterly_review / annual_plan / operations default）をクローズする"
  task close_stale: :environment do
    # クローズ対象の GitHub Issue 番号と理由
    stale_issues = [
      # operations default ticket (重複 5 件。#317 が最新なので 4 件をクローズ)
      { number: 311, reason: "operations default placeholder – duplicate" },
      { number: 312, reason: "operations default placeholder – duplicate" },
      { number: 313, reason: "operations default placeholder – duplicate" },
      { number: 314, reason: "operations default placeholder – duplicate" },
      # operations default ticket の最新も "default ticket" なので @copilot 不要
      { number: 317, reason: "operations default placeholder – no implementation needed" },
      # quarterly_review サマリー（コード実装なし）
      { number: 315, reason: "quarterly_review summary – no implementation needed" },
      { number: 319, reason: "quarterly_review summary – no implementation needed" },
      { number: 321, reason: "quarterly_review summary – no implementation needed" },
      # annual_plan サマリー（コード実装なし）
      { number: 316, reason: "annual_plan summary – no implementation needed" },
      { number: 320, reason: "annual_plan summary – no implementation needed" }
    ]

    closed = 0
    failed = 0

    stale_issues.each do |entry|
      comment = "このIssueは自動生成されたサマリーまたはプレースホルダーチケットのため、Copilot実装は不要です。Issue を自動クローズします（理由: #{entry[:reason]}）。"
      result = GithubIssueService.close_issue(issue_number: entry[:number], comment: comment)
      if result
        puts "closed ##{entry[:number]} (#{entry[:reason]})"
        closed += 1
      else
        puts "FAILED to close ##{entry[:number]}"
        failed += 1
      end
    end

    puts "\n=== 完了: closed=#{closed} failed=#{failed} ==="
  end
end
