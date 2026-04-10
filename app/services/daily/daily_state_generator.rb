module Daily
  class DailyStateGenerator
    WEEKDAY_MOOD = { 0 => +10, 1 => -20, 2 => -5, 3 => 0, 4 => +5, 5 => +15, 6 => +10 }.freeze
    SEASON_MOOD = { spring: +10, summer: +5, autumn: -5, winter: -10 }.freeze
    WEATHER_MOOD = { sunny: +15, cloudy: -5, rainy: -10, snowy: +5, normal_weather: 0 }.freeze

    BASE_DRINKING_PROB = {
      very_low: 0.03, low: 0.08, normal: 0.15, high: 0.30, very_high: 0.50
    }.freeze

    DAILY_WHIMS = %i[
      hyper melancholic nostalgic motivated lazy chatty quiet
      curious creative grateful irritable affectionate philosophical normal_whim
    ].freeze

    DAILY_WHIM_WEIGHTS = [ 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 40 ].freeze

    def self.generate(ai_user)
      new(ai_user).generate
    end

    def initialize(ai_user)
      @ai = ai_user
      @personality = ai_user.ai_personality
      @profile = ai_user.ai_profile
      @yesterday = ai_user.ai_daily_states.find_by(date: Date.yesterday)
    end

    def generate
      fatigue = carry_fatigue
      hangover = @yesterday&.is_drinking && @yesterday.drinking_level >= 2
      physical = generate_physical(fatigue, hangover)
      mood = generate_mood(physical)
      energy = generate_energy(physical, mood)
      busyness = generate_busyness
      is_drinking = generate_drinking(physical)
      drinking_level = is_drinking ? rand(1..3) : 0
      daily_whim = pick_daily_whim
      timeline_urge = generate_timeline_urge(mood)
      today_events = load_today_events
      stress_level = generate_stress_level(physical, busyness, mood)
      social_battery = generate_social_battery(energy, mood)
      concentration = generate_concentration(physical, sleep_quality: hangover ? :bad : :normal)
      appetite = generate_appetite(physical, hangover)
      morning_mood = generate_morning_mood(fatigue, hangover)
      going_out = generate_going_out(busyness, energy)

      @ai.ai_daily_states.create!(
        date: Date.current,
        physical: physical,
        mood: mood,
        energy: energy,
        busyness: busyness,
        is_drinking: is_drinking,
        drinking_level: drinking_level,
        post_motivation: 50,
        timeline_urge: timeline_urge,
        hangover: hangover || false,
        fatigue_carried: fatigue,
        daily_whim: daily_whim,
        today_events: today_events,
        stress_level: stress_level,
        social_battery: social_battery,
        concentration: concentration,
        appetite: appetite,
        morning_mood: morning_mood,
        going_out: going_out,
        hourly_states: []
      )
    end

    private

    def carry_fatigue
      prev = @yesterday&.fatigue_carried || 0
      result = prev - 10
      result += 15 if @yesterday&.busyness == "busy"
      result.clamp(0, 100)
    end

    def generate_physical(fatigue, hangover)
      score = rand(0..100)
      score -= 20 if fatigue > 50
      score -= 15 if hangover
      if score < 15
        :sick
      elsif score < 35
        :tired
      elsif score < 80
        :normal_physical
      else
        :good
      end
    end

    def generate_mood(physical)
      score = 0
      score += WEEKDAY_MOOD[Date.current.wday]
      score += SEASON_MOOD[current_season]

      range_factor = { very_low: 0.3, low: 0.6, normal: 1.0, high: 1.5, very_high: 2.0 }
      score += (rand(-15..15) * range_factor[@personality.emotional_range.to_sym]).round

      score -= 10 if @yesterday&.mood == "very_negative"
      score -= 15 if physical == :sick
      score -= 5 if physical == :tired

      classify_mood(score)
    end

    def classify_mood(score)
      if score >= 15
        :positive
      elsif score >= -5
        :neutral
      elsif score >= -20
        :negative
      else
        :very_negative
      end
    end

    def generate_energy(physical, mood)
      if physical == :sick || physical == :tired
        :low
      elsif mood == :positive && physical == :good
        :high
      else
        :normal_energy
      end
    end

    def generate_busyness
      r = rand
      if r < 0.2
        :free
      elsif r < 0.7
        :normal_busyness
      else
        :busy
      end
    end

    def generate_drinking(physical)
      return false if [ :sick, :tired ].include?(physical)

      base = BASE_DRINKING_PROB[@personality.drinking_frequency.to_sym] || 0.15
      day_mult = [ 5, 6 ].include?(Date.current.wday) ? 2.0 : 1.0
      rand < base * day_mult
    end

    def generate_timeline_urge(mood)
      if mood == :positive
        :high_urge
      elsif mood == :very_negative
        :low_urge
      else
        :normal_urge
      end
    end

    def pick_daily_whim
      weighted_sample(DAILY_WHIMS, DAILY_WHIM_WEIGHTS)
    end

    def weighted_sample(items, weights)
      total = weights.sum
      r = rand(total)
      cumulative = 0
      items.each_with_index do |item, i|
        cumulative += weights[i]
        return item if r < cumulative
      end
      items.last
    end

    def current_season
      month = Date.current.month
      case month
      when 3..5 then :spring
      when 6..8 then :summer
      when 9..11 then :autumn
      else :winter
      end
    end

    def generate_stress_level(physical, busyness, mood)
      base = 20
      base += 20 if busyness == :busy
      base += 10 if physical == :tired || physical == :sick
      base += 15 if mood == :negative || mood == :very_negative
      base -= 10 if mood == :positive
      base -= 5  if busyness == :free
      # 性格による補正（完璧主義者はストレスを感じやすい）
      perfectionism_factor = { very_low: -10, low: -5, normal: 0, high: 5, very_high: 15 }
      base += perfectionism_factor[@personality.perfectionism.to_sym] || 0
      base.clamp(0, 100)
    end

    def generate_social_battery(energy, mood)
      base = 70
      base = 40  if energy == :low
      base = 85  if energy == :high
      base -= 15 if mood == :negative || mood == :very_negative
      base += 10 if mood == :positive
      # 社交性による補正
      sociability_factor = { very_low: -20, low: -10, normal: 0, high: 10, very_high: 20 }
      base += sociability_factor[@personality.sociability.to_sym] || 0
      base.clamp(0, 100)
    end

    def generate_concentration(physical, sleep_quality:)
      if physical == :sick || sleep_quality == :bad
        :low_concentration
      elsif physical == :good
        :high_concentration
      else
        :normal_concentration
      end
    end

    def generate_appetite(physical, hangover)
      if physical == :sick || hangover
        :no_appetite
      elsif physical == :tired
        :small_appetite
      elsif [ 5, 6 ].include?(Date.current.wday)
        :big_appetite
      else
        :normal_appetite
      end
    end

    def generate_morning_mood(fatigue, hangover)
      if hangover
        :terrible_morning
      elsif fatigue > 60
        :bad_morning
      elsif fatigue > 30
        :ok_morning
      elsif WEEKDAY_MOOD[Date.current.wday] > 0
        :good_morning
      else
        :ok_morning
      end
    end

    def generate_going_out(busyness, energy)
      return false if energy == :low
      return true  if busyness == :busy

      r = rand
      busyness == :normal_busyness ? r < 0.5 : r < 0.3
    end

    def load_today_events
      events_config = YAML.load_file(Rails.root.join("config", "events.yml"))
      today = Date.current
      keys = []

      events_config["regular_events"]&.each do |ev|
        keys << ev["key"] if ev["month"] == today.month && ev["day"] == today.day
      end

      events_config["recurring"]&.each do |ev|
        keys << ev["key"] if ev["type"] == "monthly" && ev["day"] == today.day
      end

      events_config["seasonal"]&.each do |ev|
        keys << ev["key"] if ev["months"]&.include?(today.month)
      end

      keys
    end
  end
end
