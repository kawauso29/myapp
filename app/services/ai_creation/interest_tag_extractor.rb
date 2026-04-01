module AiCreation
  class InterestTagExtractor
    TAG_CATEGORIES = %w[
      食べ物・飲み物 趣味・娯楽 仕事・キャリア 恋愛・人間関係
      家族・育児 健康・体調 地域・場所 感情・気持ち
      季節・天気 ライフイベント 日常・雑談
    ].freeze

    def self.extract(ai_user)
      new(ai_user).extract
    end

    def initialize(ai_user)
      @ai_user = ai_user
      @profile = ai_user.ai_profile
    end

    def extract
      tags = collect_tags_from_profile
      tags.uniq!
      save_tags(tags)
    end

    private

    def collect_tags_from_profile
      tags = []
      tags.concat(Array(@profile.hobbies))
      tags.concat(Array(@profile.favorite_foods))
      tags.concat(Array(@profile.favorite_music))
      tags.concat(Array(@profile.favorite_places))
      tags.concat(Array(@profile.values))
      tags << @profile.occupation if @profile.occupation.present?
      tags << @profile.location if @profile.location.present?
      tags.reject(&:blank?).first(20)
    end

    def save_tags(tag_names)
      tag_names.each do |name|
        tag = InterestTag.find_or_create_by!(name: name) do |t|
          t.category = guess_category(name)
        end
        AiInterestTag.find_or_create_by!(ai_user: @ai_user, interest_tag: tag)
        tag.increment!(:usage_count)
      end
    end

    def guess_category(name)
      "日常・雑談"
    end
  end
end
