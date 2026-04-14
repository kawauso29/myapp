require "zlib"

module AiVoice
  class ProfileSelector
    VOICEVOX_PROFILES = [
      { voice_key: "voicevox:1", voice_label: "四国めたん（ノーマル）" },
      { voice_key: "voicevox:3", voice_label: "ずんだもん（ノーマル）" },
      { voice_key: "voicevox:8", voice_label: "春日部つむぎ（ノーマル）" },
      { voice_key: "voicevox:14", voice_label: "冥鳴ひまり（ノーマル）" }
    ].freeze

    ELEVENLABS_PROFILES = [
      { voice_key: "elevenlabs:rachel", voice_label: "Rachel" },
      { voice_key: "elevenlabs:adam", voice_label: "Adam" },
      { voice_key: "elevenlabs:domi", voice_label: "Domi" },
      { voice_key: "elevenlabs:bella", voice_label: "Bella" }
    ].freeze

    class << self
      def profile_for(ai_user)
        profiles = profiles_for(ai_user)
        profile = profiles.fetch(stable_index(ai_user, profiles.size))
        profile.merge(provider: provider_for(ai_user))
      end

      def voice_payload(ai_user, text:, source: nil, source_id: nil)
        profile = profile_for(ai_user)
        {
          provider: profile[:provider],
          voice_key: profile[:voice_key],
          voice_label: profile[:voice_label],
          text: text.to_s,
          source: source,
          source_id: source_id
        }
      end

      private

      def provider_for(ai_user)
        ai_user.premium_ai? ? "elevenlabs" : "voicevox"
      end

      def profiles_for(ai_user)
        provider_for(ai_user) == "elevenlabs" ? ELEVENLABS_PROFILES : VOICEVOX_PROFILES
      end

      def stable_index(ai_user, size)
        seed = "#{ai_user.id}:#{ai_user.username}:#{ai_user.premium_personality_template}"
        Zlib.crc32(seed) % size
      end
    end
  end
end
