module AiCreation
  class InputSanitizer
    NG_WORDS = YAML.load_file(Rails.root.join("config", "ng_words.yml")).freeze

    def self.sanitize(text)
      return "" if text.blank?

      sanitized = text.dup
      # HTML tags
      sanitized = ActionController::Base.helpers.strip_tags(sanitized)
      # Trim whitespace
      sanitized = sanitized.strip.gsub(/\s+/, " ")
      sanitized
    end

    def self.contains_ng_words?(text)
      return false if text.blank?

      NG_WORDS.each_value do |words|
        words.each do |word|
          return true if text.include?(word)
        end
      end
      false
    end

    def self.sanitize_profile_params(params)
      sanitized = {}
      params.each do |key, value|
        sanitized[key] = case value
                         when String then sanitize(value)
                         when Array then value.map { |v| v.is_a?(String) ? sanitize(v) : v }
                         else value
                         end
      end
      sanitized
    end
  end
end
