class SlackForwardToClaudeJob < ApplicationJob
  queue_as :default

  def perform(text:, channel:, user:, ts: nil)
    # SLACK_GITHUB_MEMBER_ID は廃止済み。転送機能は利用不可。
    Rails.logger.info("[SlackForwardToClaudeJob] 転送機能は廃止されました（SLACK_GITHUB_MEMBER_ID 削除済み）")
  end
end
