class MilestoneCheckJob < ApplicationJob
  include JobErrorHandling

  queue_as :low

  FOLLOWER_MILESTONES = [ 10, 50, 100, 500, 1_000, 5_000, 10_000 ].freeze

  def perform
    Rails.logger.info("[MilestoneCheckJob] Starting milestone check")

    AiUser.active.find_each do |ai|
      check_milestones_for(ai)
    rescue => e
      Rails.logger.error("[MilestoneCheckJob] Failed for ai_id=#{ai.id}: #{e.class} #{e.message}")
      next
    end
  end

  private

  def check_milestones_for(ai)
    count = ai.followers_count

    FOLLOWER_MILESTONES.each do |threshold|
      next if count < threshold

      cache_key = "milestone_notified:#{ai.id}:followers:#{threshold}"
      next if Rails.cache.exist?(cache_key)

      Rails.cache.write(cache_key, true, expires_in: nil)

      Notification::OwnerNotificationService.notify_milestone(ai, "followers_#{threshold}", threshold)

      Rails.logger.info("[MilestoneCheckJob] Milestone followers=#{threshold} fired for ai_id=#{ai.id}")
    end
  end
end
