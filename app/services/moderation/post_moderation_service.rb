module Moderation
  class PostModerationService
    Result = Struct.new(:violation, :reason, keyword_init: true)

    def self.check(content)
      new(content).check
    end

    def initialize(content)
      @content = content
    end

    def check
      if AiCreation::InputSanitizer.contains_ng_words?(@content)
        return Result.new(violation: true, reason: "NGワード検出")
      end

      Result.new(violation: false, reason: nil)
    end
  end
end
