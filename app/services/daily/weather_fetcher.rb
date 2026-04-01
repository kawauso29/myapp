module Daily
  class WeatherFetcher
    OPENWEATHER_URL = "https://api.openweathermap.org/data/2.5/weather".freeze
    CACHE_TTL = 12.hours.to_i
    MAX_RETRIES = 3

    CONDITION_MAP = {
      "Clear"        => "sunny",
      "Clouds"       => "cloudy",
      "Rain"         => "rainy",
      "Drizzle"      => "rainy",
      "Thunderstorm" => "rainy",
      "Snow"         => "snowy"
    }.freeze

    Result = Struct.new(:condition, :temp, keyword_init: true)

    def self.fetch(city)
      new(city).fetch
    end

    def initialize(city)
      @city = city
    end

    def fetch
      result = fetch_from_api
      cache_result(result)
      result
    rescue => e
      Rails.logger.warn("[WeatherFetcher] Failed for #{@city}: #{e.class} #{e.message}")
      fallback = Result.new(condition: "normal_weather", temp: nil)
      cache_result(fallback)
      fallback
    end

    private

    def fetch_from_api
      retries = 0
      begin
        response = HTTParty.get(
          OPENWEATHER_URL,
          query: {
            q: @city,
            appid: api_key,
            units: "metric",
            lang: "ja"
          },
          timeout: 10
        )

        raise "API error: #{response.code}" unless response.success?

        parse_response(response.parsed_response)
      rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED => e
        if retries < MAX_RETRIES
          retries += 1
          sleep(2**retries)
          retry
        end
        raise
      end
    end

    def parse_response(data)
      main_weather = data.dig("weather", 0, "main") || ""
      condition = CONDITION_MAP[main_weather] || "normal_weather"
      temp = data.dig("main", "temp")&.round

      Result.new(condition: condition, temp: temp)
    end

    def cache_result(result)
      payload = { condition: result.condition, temp: result.temp }.to_json
      $redis.setex("weather:#{@city}", CACHE_TTL, payload)
    end

    def api_key
      ENV.fetch("OPENWEATHER_API_KEY")
    end
  end
end
