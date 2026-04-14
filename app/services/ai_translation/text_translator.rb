require "digest"

module AiTranslation
  class TextTranslator
    CACHE_TTL = 12.hours

    def self.translate(text:, from:, to:)
      new(text: text, from: from, to: to).translate
    end

    def initialize(text:, from:, to:)
      @text = text.to_s
      @from = LanguageCatalog.normalize(from)
      @to = LanguageCatalog.normalize(to)
    end

    def translate
      return @text if @text.blank? || @from == @to

      Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
        translated = translate_with_llm
        translated.presence || @text
      end
    rescue => e
      Rails.logger.warn("TextTranslator failed: #{e.class}: #{e.message} (from=#{@from}, to=#{@to}, length=#{@text.length})")
      @text
    end

    private

    def cache_key
      digest = Digest::SHA256.hexdigest(@text)
      "ai_translation:v1:#{@from}:#{@to}:#{digest}"
    end

    def translate_with_llm
      prompt = <<~PROMPT
        次の文を#{LanguageCatalog.label_for(@from)}から#{LanguageCatalog.label_for(@to)}に自然に翻訳してください。
        意味を保持し、出力は翻訳文のみを返してください。

        #{@text}
      PROMPT

      LlmClient.call(prompt, purpose: :post, max_tokens: 800).to_s.strip
    end
  end
end
