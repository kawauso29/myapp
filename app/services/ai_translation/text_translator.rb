require "digest"

module AiTranslation
  class TextTranslator
    CACHE_TTL = 12.hours

    LANGUAGE_LABELS = {
      "ja" => "日本語",
      "en" => "英語",
      "ko" => "韓国語",
      "zh" => "中国語",
      "es" => "スペイン語",
      "fr" => "フランス語",
      "de" => "ドイツ語"
    }.freeze

    def self.translate(text:, from:, to:)
      new(text: text, from: from, to: to).translate
    end

    def initialize(text:, from:, to:)
      @text = text.to_s
      @from = normalize_language(from)
      @to = normalize_language(to)
    end

    def translate
      return @text if @text.blank? || @from == @to

      Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
        translated = translate_with_llm
        translated.presence || @text
      end
    rescue => e
      Rails.logger.warn("TextTranslator failed: #{e.class}: #{e.message}")
      @text
    end

    private

    def normalize_language(language)
      lang = language.to_s.downcase
      return lang if User::SUPPORTED_LANGUAGES.include?(lang)

      "ja"
    end

    def cache_key
      digest = Digest::SHA256.hexdigest(@text)
      "ai_translation:v1:#{@from}:#{@to}:#{digest}"
    end

    def translate_with_llm
      prompt = <<~PROMPT
        次の文を#{language_label(@from)}から#{language_label(@to)}に自然に翻訳してください。
        意味を保持し、出力は翻訳文のみを返してください。

        #{@text}
      PROMPT

      LlmClient.call(prompt, purpose: :post, max_tokens: 800).to_s.strip
    end

    def language_label(lang)
      LANGUAGE_LABELS[lang] || "日本語"
    end
  end
end
