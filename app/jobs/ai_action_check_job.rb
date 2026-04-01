class AiActionCheckJob < ApplicationJob
  include JobErrorHandling

  queue_as :default
  sidekiq_options retry: 2, dead: false if respond_to?(:sidekiq_options)

  LOCK_KEY = "lock:ai_action_check"
  LOCK_TTL = 14.minutes.to_i

  def perform
    redis = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"))
    acquired = redis.set(LOCK_KEY, 1, nx: true, ex: LOCK_TTL)
    unless acquired
      Rails.logger.info("AiActionCheckJob: skipped (already running)")
      return
    end

    begin
      run_action_check
    ensure
      redis.del(LOCK_KEY)
    end
  end

  private

  def run_action_check
    AiUser.where(is_active: true).find_each(batch_size: 100) do |ai|
      process_ai(ai)
    rescue => e
      Rails.logger.error("AiActionCheckJob failed for ai_id=#{ai.id}: #{e.message}")
      next
    end
  end

  def process_ai(ai)
    daily_state = ai.today_state
    return unless daily_state
    return if force_skip?(ai, daily_state)

    # 1. Read timeline & maybe like posts
    posts_to_read = AiAction::TimelineSelector.select(ai, limit: 15)
    process_timeline_likes(ai, posts_to_read)

    # 2. Find interesting post for reply
    interesting_post = find_interesting_post(ai, posts_to_read)

    # 3. Decide action: reply > post > DM > nothing
    if interesting_post && should_reply?(ai, daily_state)
      ReplyGenerateJob.perform_later(ai.id, interesting_post.id)
    elsif AiAction::ActionChecker.should_post?(ai, daily_state)
      motivation = AiAction::MotivationSelector.select(ai, daily_state)
      PostGenerateJob.perform_later(ai.id, motivation)
    elsif should_dm?(ai)
      DmCheckJob.perform_later(ai.id)
    end
  end

  def force_skip?(ai, daily_state)
    daily_state.physical == "sick" || daily_state.post_motivation < 20
  end

  def process_timeline_likes(ai, posts)
    posts.each do |post|
      next if post.ai_user_id == ai.id
      next unless should_like?(ai, post)

      AiPostLike.find_or_create_by!(ai_user: ai, ai_post: post)
      post.increment!(:ai_likes_count)
      post.increment!(:likes_count)
      AiAction::RelationshipUpdater.update(ai.id, post.ai_user_id, :liked_post)
    rescue ActiveRecord::RecordNotUnique
      next
    end
  end

  def should_like?(ai, post)
    personality = ai.ai_personality
    base = 0.15
    base += 0.1 if personality&.empathy_high? || personality&.empathy_very_high?
    base += 0.1 if personality&.sociability_high? || personality&.sociability_very_high?
    rand < base
  end

  def find_interesting_post(ai, posts)
    return nil if posts.empty?

    ai_tags = ai.interest_tags.pluck(:name).to_set
    posts.find do |post|
      next if post.ai_user_id == ai.id
      shared = (post.tags || []).to_set & ai_tags
      shared.any? || post.likes_count > 10
    end
  end

  def should_reply?(ai, daily_state)
    base = 0.15
    personality = ai.ai_personality
    base += 0.15 if personality&.sociability_high? || personality&.sociability_very_high?
    base += 0.10 if personality&.empathy_high? || personality&.empathy_very_high?
    base += 0.10 if daily_state.daily_whim == "chatty"
    base -= 0.10 if daily_state.daily_whim == "quiet"
    rand < base
  end

  def should_dm?(ai)
    personality = ai.ai_personality
    return false unless personality&.sociability_high? || personality&.sociability_very_high?

    rand < 0.05
  end
end
