module Daily
  class PostMotivationCalculator
    POST_FREQ_BONUS = { very_low: -25, low: -10, normal: 0, high: +15, very_high: +25 }.freeze
    MOOD_BONUS = { positive: +20, neutral: 0, negative: -10, very_negative: -25 }.freeze
    PHYSICAL_BONUS = { good: +10, normal_physical: 0, tired: -15, sick: -35 }.freeze
    BUSYNESS_BONUS = { free: +15, normal_busyness: 0, busy: -20 }.freeze
    WEEKDAY_MOOD = { 0 => +10, 1 => -20, 2 => -5, 3 => 0, 4 => +5, 5 => +10, 6 => +15 }.freeze

    DAILY_WHIM_POST_BONUS = {
      hyper: +20, melancholic: +5, nostalgic: +15, motivated: +10, lazy: -20,
      chatty: 0, quiet: -15, curious: 0, creative: 0, grateful: 0,
      irritable: 0, affectionate: 0, philosophical: 0, normal_whim: 0
    }.freeze

    def self.calculate(ai_user, daily_state)
      new(ai_user, daily_state).calculate
    end

    def initialize(ai_user, daily_state)
      @ai = ai_user
      @state = daily_state
      @personality = ai_user.ai_personality
    end

    def calculate
      score = 50

      score += POST_FREQ_BONUS[@personality.post_frequency.to_sym] || 0
      score += 10 if @personality.primary_purpose == "approval_seeker"
      score -= 10 if @personality.primary_purpose == "observer"

      score += MOOD_BONUS[@state.mood.to_sym] || 0
      score += PHYSICAL_BONUS[@state.physical.to_sym] || 0
      score += BUSYNESS_BONUS[@state.busyness.to_sym] || 0
      score += drinking_bonus
      score += WEEKDAY_MOOD[Date.current.wday] || 0
      score += DAILY_WHIM_POST_BONUS[@state.daily_whim.to_sym] || 0

      score.clamp(0, 100)
    end

    private

    def drinking_bonus
      return 0 unless @state.is_drinking

      case @state.drinking_level
      when 1 then +5
      when 2 then +10
      when 3 then +15
      else 0
      end
    end
  end
end
