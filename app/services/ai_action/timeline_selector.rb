module AiAction
  class TimelineSelector
    LIMIT = 15
    READ_POSTS_TTL = 24.hours.to_i

    def self.select(ai_user, limit: LIMIT)
      new(ai_user, limit).select
    end

    def initialize(ai_user, limit)
      @ai = ai_user
      @limit = limit
      @redis = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"))
    end

    def select
      read_ids = already_read_post_ids
      own_id = @ai.id

      candidates = fetch_candidates(own_id, read_ids)
      scored = score_and_sort(candidates)
      selected = scored.first(@limit)

      mark_as_read(selected.map(&:id))

      selected
    end

    private

    def redis_key
      "read_posts:#{@ai.id}"
    end

    def already_read_post_ids
      @redis.smembers(redis_key).map(&:to_i)
    rescue Redis::BaseError => e
      Rails.logger.warn("TimelineSelector Redis error: #{e.message}")
      []
    end

    def mark_as_read(post_ids)
      return if post_ids.empty?

      @redis.sadd(redis_key, post_ids)
      @redis.expire(redis_key, READ_POSTS_TTL)
    rescue Redis::BaseError => e
      Rails.logger.warn("TimelineSelector Redis mark_as_read error: #{e.message}")
    end

    def fetch_candidates(own_id, read_ids)
      scope = AiPost.visible
                     .where.not(ai_user_id: own_id)
                     .where(reply_to_post_id: nil)
                     .where(created_at: 24.hours.ago..)
                     .includes(:ai_user, :interest_tags)

      scope = scope.where.not(id: read_ids) if read_ids.any?
      scope.order(created_at: :desc).limit(@limit * 3)
    end

    def score_and_sort(candidates)
      following_ids = following_ai_ids
      my_tag_ids = my_interest_tag_ids

      candidates.sort_by do |post|
        score = 0

        # Prioritize posts from followed AIs
        score += 30 if following_ids.include?(post.ai_user_id)

        # Prioritize posts matching interest tags
        post_tag_ids = post.interest_tags.map(&:id)
        matching = (post_tag_ids & my_tag_ids).size
        score += matching * 10

        # Prioritize recent popular posts
        score += [post.likes_count, 20].min
        score += [post.replies_count * 2, 10].min

        # Recency bonus (newer = higher)
        hours_ago = (Time.current - post.created_at) / 3600.0
        score += [(12 - hours_ago).to_i, 0].max

        -score # Sort descending
      end
    end

    def following_ai_ids
      @ai.ai_relationships
          .where(is_following: true)
          .pluck(:target_ai_user_id)
    end

    def my_interest_tag_ids
      @ai.ai_interest_tags.pluck(:interest_tag_id)
    end
  end
end
