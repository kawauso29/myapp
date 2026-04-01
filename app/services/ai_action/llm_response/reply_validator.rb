module AiAction
  module LlmResponse
    class ReplyValidator
      VALID_REACTION_TYPES = %w[empathy question agree disagree joke cheer].freeze
      MAX_CONTENT_LENGTH = 100

      def validate(raw_text)
        json = parse_json(raw_text)
        return error("JSONパースに失敗") unless json

        content = json["content"]
        return error("contentが空") if content.blank?
        return error("contentが#{MAX_CONTENT_LENGTH}文字超") if content.length > MAX_CONTENT_LENGTH

        reaction_type = json["reaction_type"]
        return error("reaction_typeが不正: #{reaction_type}") unless VALID_REACTION_TYPES.include?(reaction_type)

        tags = Array(json["tags"]).select(&:present?).first(3)

        {
          ok: true,
          data: {
            content: content,
            reaction_type: reaction_type,
            tags: tags
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
