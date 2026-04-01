module Moderation
  class ProfileModerationService
    Result = Struct.new(:ok, :reason, keyword_init: true)

    def self.check(profile_params)
      text = [
        profile_params[:name],
        profile_params[:personality_note],
        profile_params[:bio],
        profile_params[:occupation]
      ].compact.join(" ")

      if AiCreation::InputSanitizer.contains_ng_words?(text)
        return Result.new(ok: false, reason: "不適切な表現が含まれています")
      end

      Result.new(ok: true, reason: nil)
    end
  end
end
