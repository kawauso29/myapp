class OwnerScoreUpdateJob < ApplicationJob
  include JobErrorHandling

  queue_as :low

  def perform
    User.find_each(batch_size: 100) do |user|
      score = user.ai_users.sum do |ai|
        ai.followers_count * 10 +
        ai.total_likes * 1 +
        (ai.posts_count * 0.1)
      end.round
      user.update!(owner_score: score)
    rescue => e
      Rails.logger.error("OwnerScoreUpdateJob failed for user_id=#{user.id}: #{e.message}")
      next
    end
  end
end
