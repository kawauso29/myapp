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

    # 関係タイプ別の基本波及係数（close_friendほど感情が波及しやすい）
    RIPPLE_BASE_COEFFICIENT = { close_friend: 1.0, friend: 0.7 }.freeze
    # interaction_score (0–100) が波及係数に最大 +0.5 の追加ブーストを与える
    RIPPLE_SCORE_BOOST_DIVISOR = 200.0

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
      score = weighted_sad_friend_score
      [ (score * FRIEND_CONCERN_MOTIVATION_DELTA).round, FRIEND_CONCERN_MOTIVATION_DELTA * 3 ].min
    end

    def friend_concern_stress_delta
      score = weighted_sad_friend_score
      [ (score * FRIEND_CONCERN_STRESS_DELTA).round, FRIEND_CONCERN_STRESS_DELTA * 3 ].min
    end

    # interaction_score で重み付けされた「落ち込んでいる友人」スコアを返す。
    # 関係タイプが close_friend ほど、また interaction_score が高いほど係数が大きくなる。
    def weighted_sad_friend_score
      return 0.0 if connected_ai_ids.empty?

      sad_ai_ids = AiDailyState.where(ai_user_id: connected_ai_ids, date: @date,
                                      mood: [ :negative, :very_negative ]).pluck(:ai_user_id)
      return 0.0 if sad_ai_ids.empty?

      sad_ai_ids.sum do |ai_id|
        rel = relationship_score_map[ai_id]
        next 0.0 unless rel

        ripple_coefficient(rel[:type], rel[:score])
      end
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

    # 波及係数 = 関係タイプの基本値 + interaction_score による追加ブースト
    def ripple_coefficient(relationship_type, interaction_score)
      base = RIPPLE_BASE_COEFFICIENT[relationship_type.to_sym] || 0.5
      boost = interaction_score.to_f / RIPPLE_SCORE_BOOST_DIVISOR
      base + boost
    end

    # ai_user_id → { type:, score: } のマップを返す
    def relationship_score_map
      @relationship_score_map ||= connected_relationships.each_with_object({}) do |rel, hash|
        hash[rel[:ai_id]] = rel
      end
    end

    def connected_relationships
      @connected_relationships ||= begin
        rels = AiRelationship
          .where(ai_user_id: @ai.id, relationship_type: [ :friend, :close_friend ])
          .select(:target_ai_user_id, :relationship_type, :interaction_score)
          .map { |r| { ai_id: r.target_ai_user_id, type: r.relationship_type.to_sym, score: r.interaction_score } }

        reverse_rels = AiRelationship
          .where(target_ai_user_id: @ai.id, relationship_type: [ :friend, :close_friend ])
          .select(:ai_user_id, :relationship_type, :interaction_score)
          .map { |r| { ai_id: r.ai_user_id, type: r.relationship_type.to_sym, score: r.interaction_score } }

        (rels + reverse_rels).uniq { |r| r[:ai_id] }
      end
    end

    def connected_ai_ids
      @connected_ai_ids ||= connected_relationships.map { |r| r[:ai_id] }
    end
  end
end
