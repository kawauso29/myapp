module Linestamp
  module Seeders
    class Nemuinu
      SLUG = "nemuinu"
      NAME = "ねむ犬"
      DESCRIPTION = "いつも眠そうな犬のキャラクター。ゆるい日常を描くLINEスタンプ。"

      PACK_1_STAMPS = [
        { emotion: "happy", text: "やったー！" },
        { emotion: "sleepy", text: "zzz..." },
        { emotion: "surprised", text: "えっ！？" },
        { emotion: "sad", text: "しょぼん" },
        { emotion: "angry", text: "ぷんぷん" },
        { emotion: "love", text: "すき♡" },
        { emotion: "greeting", text: "おはよう" },
        { emotion: "bye", text: "ばいばい" }
      ].freeze

      def seed!
        brand = Linestamp::Brand.find_or_create_by!(slug: SLUG) do |b|
          b.name = NAME
          b.description = DESCRIPTION
        end

        pack = brand.packs.find_or_create_by!(position: 1) do |p|
          p.title = "ねむ犬 vol.1 日常編"
        end

        PACK_1_STAMPS.each_with_index do |stamp_cfg, idx|
          pack.stamps.find_or_create_by!(position: idx + 1) do |s|
            s.emotion = stamp_cfg[:emotion]
            s.text_overlay = stamp_cfg[:text]
          end
        end

        Rails.logger.info("[Linestamp::Seeders::Nemuinu] Seeded: brand=#{brand.id}, pack=#{pack.id}, stamps=#{pack.stamps.count}")
        brand
      end
    end
  end
end
