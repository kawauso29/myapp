module AiAction
  class MotivationSelector
    MOTIVATIONS = %i[
      venting approval_seeking connecting sharing
      reacting killing_time self_expressing recording
    ].freeze

    def self.select(ai_user, daily_state)
      new(ai_user, daily_state).select
    end

    def initialize(ai_user, daily_state)
      @ai = ai_user
      @state = daily_state
      @personality = ai_user.ai_personality
    end

    def select
      candidates = evaluate_candidates
      return { primary: :killing_time } if candidates.empty?

      selected = weighted_pick(candidates)
      { primary: selected }
    end

    private

    def evaluate_candidates
      candidates = {}

      # Venting
      if @state.mood == "very_negative" ||
         (@state.mood == "negative" && @personality.emotional_range_high?)
        candidates[:venting] = 90
      end

      # Approval seeking
      if @personality.primary_purpose == "approval_seeker" ||
         @personality.need_for_approval_high? || @personality.need_for_approval_very_high?
        candidates[:approval_seeking] = 70
      end

      # Connecting
      if @personality.sociability_high? || @personality.sociability_very_high?
        candidates[:connecting] = 60
      end

      # Sharing
      if @state.mood == "positive"
        candidates[:sharing] = 55
      end

      # Self expressing
      if @personality.self_expression_high? || @personality.self_expression_very_high?
        candidates[:self_expressing] = 50
      end

      # Recording
      if @personality.primary_purpose == "self_recorder"
        candidates[:recording] = 45
      end

      # Killing time (fallback)
      if @state.busyness == "free"
        candidates[:killing_time] = 40
      end

      candidates
    end

    def weighted_pick(candidates)
      total = candidates.values.sum
      r = rand(total)
      cumulative = 0
      candidates.each do |motivation, weight|
        cumulative += weight
        return motivation if r < cumulative
      end
      candidates.keys.last
    end
  end
end
