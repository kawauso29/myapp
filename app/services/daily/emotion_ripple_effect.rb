module Daily
  class EmotionRippleEffect
    POPULAR_FOLLOWERS_THRESHOLD = 50
    POPULAR_POSTS_THRESHOLD = 30
    FLAME_REPORT_THRESHOLD = 3
    FLAME_STRESS_DELTA = 12
    FRIEND_CONCERN_MOTIVATION_DELTA = 6
    FRIEND_CONCERN_STRESS_DELTA = 4
    BRIGHT_TIMELINE_MIN_POSTS = 8
    BRIGHT_TIMELINE_POSITIVE_RATIO = 0.7
    BRIGHT_TIMELINE_STRESS_DELTA = -8
    BRIGHT_TIMELINE_MOTIVATION_DELTA = 6

    def self.deltas(ai_user, date: Date.current)
      new(ai_user, date: date).deltas
    end

    def initialize(ai_user, date: Date.current)
      @ai = ai_user
      @date = date
    end

    def deltas
      {
        stress_delta: flame_stress_delta + friend_concern_stress_delta + bright_timeline_stress_delta,
        post_motivation_delta: friend_concern_motivation_delta + bright_timeline_motivation_delta
      }
    end

    private

    def flame_stress_delta
      flame_count = flame_post_ids.count
      [ flame_count * FLAME_STRESS_DELTA, FLAME_STRESS_DELTA * 2 ].min
    end

    def flame_post_ids
      return [] if popular_connected_ai_ids.empty?

      post_ids = AiPost.where(
        ai_user_id: popular_connected_ai_ids,
        created_at: @date.all_day,
        mood_expressed: :negative
      ).pluck(:id)
      return [] if post_ids.empty?

      PostReport.where(ai_post_id: post_ids, status: :pending)
                .group(:ai_post_id)
                .count
                .select { |_, count| count >= FLAME_REPORT_THRESHOLD }
                .keys
    end

    def popular_connected_ai_ids
      @popular_connected_ai_ids ||= AiUser.where(id: connected_ai_ids)
                                          .where(
                                            "followers_count >= :followers OR posts_count >= :posts",
                                            followers: POPULAR_FOLLOWERS_THRESHOLD,
                                            posts: POPULAR_POSTS_THRESHOLD
                                          )
                                          .pluck(:id)
    end

    def friend_concern_motivation_delta
      [ sad_friend_count * FRIEND_CONCERN_MOTIVATION_DELTA, FRIEND_CONCERN_MOTIVATION_DELTA * 3 ].min
    end

    def friend_concern_stress_delta
      [ sad_friend_count * FRIEND_CONCERN_STRESS_DELTA, FRIEND_CONCERN_STRESS_DELTA * 3 ].min
    end

    def sad_friend_count
      return 0 if connected_ai_ids.empty?

      AiDailyState.where(ai_user_id: connected_ai_ids, date: @date, mood: [ :negative, :very_negative ]).count
    end

    def bright_timeline_stress_delta
      bright_timeline? ? BRIGHT_TIMELINE_STRESS_DELTA : 0
    end

    def bright_timeline_motivation_delta
      bright_timeline? ? BRIGHT_TIMELINE_MOTIVATION_DELTA : 0
    end

    def bright_timeline?
      timeline_posts = AiPost.where(created_at: @date.all_day)
      total = timeline_posts.count
      return false if total < BRIGHT_TIMELINE_MIN_POSTS

      positive = timeline_posts.where(mood_expressed: :positive).count
      (positive.to_f / total) >= BRIGHT_TIMELINE_POSITIVE_RATIO
    end

    def connected_ai_ids
      @connected_ai_ids ||= begin
        pairs = AiRelationship.where(ai_user_id: @ai.id, relationship_type: [ :friend, :close_friend ])
                              .or(AiRelationship.where(target_ai_user_id: @ai.id,
                                                      relationship_type: [ :friend, :close_friend ]))
                              .pluck(:ai_user_id, :target_ai_user_id)
        pairs.flatten.uniq - [ @ai.id ]
      end
    end
  end
end
