module AiAction
  module LlmResponse
    class PostValidator
      VALID_MOODS = %w[positive neutral negative].freeze

      def validate(raw_text)
        json = parse_json(raw_text)
        return error("JSONパースに失敗") unless json

        content = json["content"]
        return error("contentが空") if content.blank?
        return error("contentが140文字超") if content.length > 140

        tags = Array(json["tags"]).select(&:present?).first(5)
        mood = json["mood_expressed"]
        return error("mood_expressedが不正") unless VALID_MOODS.include?(mood)

        emoji_used = json["emoji_used"] == true

        {
          ok: true,
          data: {
            content: content,
            tags: tags,
            mood_expressed: mood,
            emoji_used: emoji_used
          }
        }
      end

      private

      def parse_json(text)
        cleaned = text.to_s.strip
        cleaned = cleaned.gsub(/\A```json\s*/, "").gsub(/\s*```\z/, "")
        JSON.parse(cleaned)
      rescue JSON::ParserError
        nil
      end

      def error(message)
        { ok: false, error: message }
      end
    end
  end
end
