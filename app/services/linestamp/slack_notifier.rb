module Linestamp
  class SlackNotifier
    CHANNEL = ENV.fetch("LINESTAMP_SLACK_CHANNEL", "#linestamp")

    def self.notify(text:, blocks: nil)
      new.notify(text: text, blocks: blocks)
    end

    def notify(text:, blocks: nil)
      return unless client

      params = { channel: CHANNEL, text: text }
      params[:blocks] = blocks if blocks
      client.chat_postMessage(**params)
    rescue Slack::Web::Api::Errors::SlackError => e
      Rails.logger.error("[Linestamp::SlackNotifier] Slack API error: #{e.message}")
    rescue StandardError => e
      Rails.logger.error("[Linestamp::SlackNotifier] Error: #{e.message}")
    end

    private

    def client
      return @client if defined?(@client)

      token = ENV["LINESTAMP_SLACK_BOT_TOKEN"] || ENV["SLACK_BOT_TOKEN"]
      return @client = nil unless token.present?

      @client = Slack::Web::Client.new(token: token)
    end
  end
end
