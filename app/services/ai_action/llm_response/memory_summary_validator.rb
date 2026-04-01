module AiAction
  module LlmResponse
    class MemorySummaryValidator
      MAX_LENGTH = 500

      def validate(raw_text)
        summary = raw_text.to_s.strip

        return error("要約が空です") if summary.blank?
        return error("要約が#{MAX_LENGTH}文字を超えています") if summary.length > MAX_LENGTH

        { ok: true, summary: summary }
      end

      private

      def error(message)
        { ok: false, error: message }
      end
    end
  end
end
