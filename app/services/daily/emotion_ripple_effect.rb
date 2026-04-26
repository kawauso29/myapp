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
    INTERACTION_SCORE_SCALE = 200.0

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
      weighted_flame = flame_connection_weight_sum
      [ (weighted_flame * FLAME_STRESS_DELTA).round, FLAME_STRESS_DELTA * 2 ].min
    end

    def flaming_author_ids
      return [] if popular_connected_ai_ids.empty?

      post_id_to_author = AiPost.where(
        ai_user_id: popular_connected_ai_ids,
        created_at: @date.all_day,
        mood_expressed: :negative
      ).pluck(:id, :ai_user_id).to_h
      return [] if post_id_to_author.empty?

      PostReport.where(ai_post_id: post_id_to_author.keys, status: :pending)
                .group(:ai_post_id)
                .count
                .select { |_, count| count >= FLAME_REPORT_THRESHOLD }
                .keys
                .map { |post_id| post_id_to_author[post_id] }
                .compact
                .uniq
    end

    def popular_connected_ai_ids
      @popular_connected_ai_ids ||= AiUser.where(id: connection_weight_by_ai_id.keys)
                                          .where(
                                            "followers_count >= :followers OR posts_count >= :posts",
                                            followers: POPULAR_FOLLOWERS_THRESHOLD,
                                            posts: POPULAR_POSTS_THRESHOLD
                                          )
                                          .pluck(:id)
    end

    def friend_concern_motivation_delta
      [ (sad_friend_weight_sum * FRIEND_CONCERN_MOTIVATION_DELTA).round, FRIEND_CONCERN_MOTIVATION_DELTA * 3 ].min
    end

    def friend_concern_stress_delta
      [ (sad_friend_weight_sum * FRIEND_CONCERN_STRESS_DELTA).round, FRIEND_CONCERN_STRESS_DELTA * 3 ].min
    end

    def sad_friend_weight_sum
      return 0.0 if connection_weight_by_ai_id.empty?

      AiDailyState.where(ai_user_id: connection_weight_by_ai_id.keys, date: @date, mood: [ :negative, :very_negative ])
                  .pluck(:ai_user_id)
                  .sum { |ai_id| connection_weight_by_ai_id[ai_id] || 0.0 }
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

    def flame_connection_weight_sum
      flaming_author_ids.sum { |ai_id| connection_weight_by_ai_id[ai_id] || 0.0 }
    end

    def connection_weight_by_ai_id
      @connection_weight_by_ai_id ||= begin
        relation_rows = AiRelationship.where(ai_user_id: @ai.id, relationship_type: [ :friend, :close_friend ])
                                      .or(
                                        AiRelationship.where(target_ai_user_id: @ai.id,
                                                             relationship_type: [ :friend, :close_friend ])
                                      )
                                      .pluck(:ai_user_id, :target_ai_user_id, :relationship_type, :interaction_score)

        relation_rows.each_with_object({}) do |(source_id, target_id, relationship_type, interaction_score), memo|
          target_id_for_ai = source_id == @ai.id ? target_id : source_id
          weight = relationship_weight(relationship_type, interaction_score)
          memo[target_id_for_ai] = [ memo[target_id_for_ai] || 0.0, weight ].max
        end
      end
    end

    def relationship_weight(relationship_type, interaction_score)
      close_friend_value = AiRelationship.relationship_types[:close_friend]
      is_close_friend = relationship_type == close_friend_value ||
                        relationship_type.to_s == "close_friend"
      closeness = is_close_friend ? 1.0 : 0.7
      interaction_factor = 0.5 + (interaction_score.to_f / INTERACTION_SCORE_SCALE)
      closeness * interaction_factor
    end
  end
end
