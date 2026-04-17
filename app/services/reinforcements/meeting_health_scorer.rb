module Reinforcements
  # Phase 25 / 補強15: 会議終了時に meeting_health_score を算出・保存し、
  # 2 期連続で threshold を下回った場合は improvement 起票対象であることを示す。
  class MeetingHealthScorer
    UNHEALTHY_STREAK_THRESHOLD = MeetingLedger::DEFAULT_HEALTH_SCORE_THRESHOLD

    def self.score!(meeting)
      score = meeting.compute_meeting_health_score
      return meeting if score.nil?

      meeting.update!(meeting_health_score: score)
      meeting
    end

    # 指定 meeting_key の直近 N 期が全て threshold を下回っているか判定する。
    # improvement 起票判断は呼び出し側（improvement_detector）が担当する。
    def self.unhealthy_streak?(meeting_key:, streak: 2, threshold: UNHEALTHY_STREAK_THRESHOLD)
      recent = MeetingLedger.where(meeting_key: meeting_key)
                            .where.not(meeting_health_score: nil)
                            .order(held_at: :desc)
                            .limit(streak)
      return false if recent.size < streak

      recent.all? { |m| m.meeting_health_score.to_f < threshold }
    end
  end
end
