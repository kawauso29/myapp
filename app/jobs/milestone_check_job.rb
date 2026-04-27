class MilestoneCheckJob < ApplicationJob
  include JobErrorHandling

  queue_as :low

  FOLLOWER_MILESTONES = [ 10, 50, 100, 500, 1_000, 5_000, 10_000 ].freeze
  LIKES_MILESTONES    = [ 100, 500, 1_000, 5_000, 10_000 ].freeze

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
    check_likes_milestones(ai)
    check_first_post_milestone(ai)
    check_first_friend_milestone(ai)
    check_first_close_friend_milestone(ai)
  end

  def check_follower_milestones(ai)
    count = ai.followers_count
    FOLLOWER_MILESTONES.each do |threshold|
      next if count < threshold

      # Keep original cache key format for backward compatibility
      fire_milestone(ai, "followers_#{threshold}", threshold, cache_key: "milestone_notified:#{ai.id}:followers:#{threshold}")
    end
  end

  def check_likes_milestones(ai)
    count = ai.total_likes
    LIKES_MILESTONES.each do |threshold|
      next if count < threshold

      fire_milestone(ai, "total_likes_#{threshold}", threshold)
    end
  end

  def check_first_post_milestone(ai)
    return if ai.posts_count < 1

    fire_milestone(ai, "first_post", 1)
  end

  def check_first_friend_milestone(ai)
    has_friend = ai.ai_relationships
                   .where(relationship_type: [ AiRelationship.relationship_types[:friend],
                                               AiRelationship.relationship_types[:close_friend] ])
                   .exists?
    return unless has_friend

    fire_milestone(ai, "first_friend", 1)
  end

  def check_first_close_friend_milestone(ai)
    has_close_friend = ai.ai_relationships
                         .where(relationship_type: AiRelationship.relationship_types[:close_friend])
                         .exists?
    return unless has_close_friend

    fire_milestone(ai, "first_close_friend", 1)
  end

  def fire_milestone(ai, milestone, value, cache_key: "milestone_notified:#{ai.id}:#{milestone}")
    return if Rails.cache.exist?(cache_key)

    Rails.cache.write(cache_key, true, expires_in: nil)

    Notification::OwnerNotificationService.notify_milestone(ai, milestone, value)

    Rails.logger.info("[MilestoneCheckJob] Milestone #{milestone} fired for ai_id=#{ai.id}")
  end
end
