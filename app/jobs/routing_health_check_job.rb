require "net/http"

class RoutingHealthCheckJob < ApplicationJob
  queue_as :default

  ROUTES_TO_CHECK = %w[
    /up
    /api/v1/ai_users
    /admin/ai_sns
  ].freeze

  HOST_HEADER = "133.167.124.112"
  BASE_URL = "http://localhost"

  def perform
    failures = []

    ROUTES_TO_CHECK.each do |path|
      status = check_route(path)
      unless status == 200
        failures << { path: path, status: status }
        Rails.logger.warn("[RoutingHealthCheckJob] #{path} returned #{status}")
      end
    end

    if failures.any?
      message = failures.map { |f| "#{f[:path]} => #{f[:status]}" }.join(", ")
      SlackNotifierService.notify(
        text: ":rotating_light: *ルーティング異常を検知* #{message}",
        color: :danger,
        fields: failures.map { |f| { title: f[:path], value: f[:status].to_s } }
      )
    end
  end

  private

  def check_route(path)
    uri = URI.parse("#{BASE_URL}#{path}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.open_timeout = 10
    http.read_timeout = 10

    request = Net::HTTP::Get.new(uri.request_uri)
    request["Host"] = HOST_HEADER

    response = http.request(request)
    response.code.to_i
  rescue => e
    Rails.logger.error("[RoutingHealthCheckJob] Network error for #{path}: #{e.message}")
    0
  end
end
