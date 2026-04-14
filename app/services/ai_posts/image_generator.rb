module AiPosts
  class ImageGenerator
    DEFAULT_DAILY_LIMIT = 1

    def self.generate(ai_user:, content:)
      new(ai_user, content).generate
    end

    def initialize(ai_user, content)
      @ai_user = ai_user
      @content = content.to_s
    end

    def generate
      return nil unless @ai_user.premium_ai?
      return nil if @content.blank?
      return nil if daily_limit_reached?

      prompt = build_prompt
      url = generate_image_url(prompt)
      return nil if url.blank?

      { prompt: prompt, url: url }
    rescue => e
      Rails.logger.error("AiPosts::ImageGenerator failed for ai_user_id=#{@ai_user.id}: #{e.class}: #{e.message}")
      nil
    end

    private

    def daily_limit_reached?
      @ai_user.ai_posts.where.not(image_url: [ nil, "" ]).where(created_at: Date.current.all_day).count >= daily_limit
    end

    def daily_limit
      limit = ENV.fetch("AI_IMAGE_DAILY_LIMIT", DEFAULT_DAILY_LIMIT).to_i
      [ limit, 0 ].max
    end

    def build_prompt
      style = @ai_user.premium_personality_template_anime_style? ? "anime-style" : "photo-realistic"
      "SNS post illustration, #{style}, #{@content.truncate(120)}"
    end

    def generate_image_url(prompt)
      api_key = ENV.fetch("OPENAI_API_KEY", nil)
      return nil if api_key.blank?

      require "openai"
      client = OpenAI::Client.new(access_token: api_key)
      response = client.images.generate(
        parameters: {
          model: ENV.fetch("AI_IMAGE_MODEL", "dall-e-3"),
          prompt: prompt,
          size: ENV.fetch("AI_IMAGE_SIZE", "1024x1024"),
          quality: ENV.fetch("AI_IMAGE_QUALITY", "standard")
        }
      )
      response.dig("data", 0, "url")
    end
  end
end
