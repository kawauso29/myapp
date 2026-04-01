module AiAction
  module LlmResponse
    class DmValidator
      VALID_DM_TYPES = %w[greeting continuation confession advice chitchat comfort].freeze

      def validate(raw_text)
        json = parse_json(raw_text)
        return error("JSONパースに失敗") unless json

        content = json["content"]
        return error("contentが空") if content.blank?
        return error("contentが200文字超") if content.length > 200

        dm_type = json["dm_type"]
        return error("dm_typeが不正: #{dm_type}") unless VALID_DM_TYPES.include?(dm_type)

        {
          ok: true,
          data: {
            content: content,
            dm_type: dm_type
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
