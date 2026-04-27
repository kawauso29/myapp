class MilestoneCheckJob < ApplicationJob
  include JobErrorHandling

  queue_as :low

  FOLLOWER_MILESTONES = [ 10, 50, 100, 500, 1_000, 5_000, 10_000 ].freeze
  LIKE_MILESTONES     = [ 100, 500, 1_000, 10_000 ].freeze

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
    check_follower_milestones(ai)
    check_first_post(ai)
    check_like_milestones(ai)
    check_first_friend(ai)
    check_first_love(ai)
  end

  def check_follower_milestones(ai)
    count = ai.followers_count
    FOLLOWER_MILESTONES.each do |threshold|
      next if count < threshold

      fire_once(ai, "followers_#{threshold}") do
        Notification::OwnerNotificationService.notify_milestone(ai, "followers_#{threshold}", threshold)
      end
    end
  end

  def check_first_post(ai)
    return if ai.posts_count < 1

    fire_once(ai, "first_post") do
      Notification::OwnerNotificationService.notify_milestone(ai, "first_post", 1)
    end
  end

  def check_like_milestones(ai)
    count = ai.total_likes
    LIKE_MILESTONES.each do |threshold|
      next if count < threshold

      fire_once(ai, "likes_#{threshold}") do
        Notification::OwnerNotificationService.notify_milestone(ai, "likes_#{threshold}", threshold)
      end
    end
  end

  def check_first_friend(ai)
    return unless ai.ai_relationships.where(relationship_type: [ :friend, :close_friend ]).exists?

    fire_once(ai, "first_friend") do
      Notification::OwnerNotificationService.notify_milestone(ai, "first_friend", 1)
    end
  end

  def check_first_love(ai)
    return unless ai.ai_relationships.where(relationship_type: :close_friend).exists?

    fire_once(ai, "first_love") do
      Notification::OwnerNotificationService.notify_milestone(ai, "first_love", 1)
    end
  end

  # Fires the block exactly once per (ai, key) pair using Rails cache.
  def fire_once(ai, key)
    cache_key = "milestone_notified:#{ai.id}:#{key}"
    return if Rails.cache.exist?(cache_key)

    Rails.cache.write(cache_key, true, expires_in: nil)
    yield
    Rails.logger.info("[MilestoneCheckJob] Milestone #{key} fired for ai_id=#{ai.id}")
  end
end
