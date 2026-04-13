class ImprovementLog < ApplicationRecord
  validates :observation, presence: true

  scope :recent, -> { order(created_at: :desc) }

  # AutonomousImprovementJob の1実行分を記録する
  def self.record!(observation:, analysis:, execution:)
    create!(
      observation:       observation,
      summary:           analysis["summary"],
      quick_win_results: execution["quick_win_results"],
      feature_proposals: analysis["feature_proposals"],
      applied_quick_wins: execution["applied_quick_wins"].to_i,
      created_pr_numbers: execution["created_pr_numbers"]
    )
  rescue => e
    Rails.logger.error("[ImprovementLog.record!] failed: #{e.message}")
    nil
  end

  # LLM プロンプトに渡す直近の改善サマリ（重複提案防止）
  def self.recent_summaries(limit: 5)
    recent.limit(limit).pluck(:summary, :created_at).map do |summary, created_at|
      "#{created_at.strftime('%m/%d %H:%M')}: #{summary}"
    end
  end

  # 直近で提案済みのfeature_proposalタイトルセット（重複 PR 防止）
  def self.recent_feature_titles(limit: 10)
    recent.limit(limit).pluck(:feature_proposals)
      .flat_map { |proposals| Array(proposals).map { |p| p.is_a?(Hash) ? p["title"] : nil } }
      .compact
      .to_set
  end
end
