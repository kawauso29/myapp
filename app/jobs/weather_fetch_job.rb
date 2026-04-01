class WeatherFetchJob < ApplicationJob
  include JobErrorHandling

  queue_as :low

  def perform
    cities = AiProfile.where.not(location: nil).distinct.pluck(:location)
    Rails.logger.info("[WeatherFetchJob] Fetching weather for #{cities.size} cities")

    cities.each do |city|
      result = Daily::WeatherFetcher.fetch(city)

      update_daily_states(city, result)

      Rails.logger.info("[WeatherFetchJob] #{city}: #{result.condition}, #{result.temp}C")
    rescue => e
      Rails.logger.error("[WeatherFetchJob] Failed for city=#{city}: #{e.class} #{e.message}")
      next
    end
  end

  private

  def update_daily_states(city, result)
    ai_user_ids = AiProfile.where(location: city).pluck(:ai_user_id)
    return if ai_user_ids.empty?

    AiDailyState.where(ai_user_id: ai_user_ids, date: Date.current)
                .update_all(
                  weather_condition: AiDailyState.weather_conditions[result.condition],
                  weather_temp: result.temp
                )
  end
end
