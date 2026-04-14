module AiTranslation
  module LanguageCatalog
    LABELS = {
      "ja" => "日本語",
      "en" => "英語",
      "ko" => "韓国語",
      "zh" => "中国語",
      "es" => "スペイン語",
      "fr" => "フランス語",
      "de" => "ドイツ語"
    }.freeze

    module_function

    def normalize(language)
      code = language.to_s.downcase
      User::SUPPORTED_LANGUAGES.include?(code) ? code : "ja"
    end

    def label_for(language)
      LABELS[normalize(language)] || "日本語"
    end
  end
end
