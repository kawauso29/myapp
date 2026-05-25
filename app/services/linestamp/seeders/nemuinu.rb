module Linestamp
  module Seeders
    class Nemuinu
      SLUG = "nemuinu"
      CHARACTER_NAME = "ねむ犬"
      SERIES_NAME = "在宅ワークのゆる犬"
      DESCRIPTION = "いつも眠そうな犬のキャラクター。ゆるい日常を描くLINEスタンプ。"

      PACK_1_STAMPS = [
        { label: "やったー！", intent: "喜び" },
        { label: "zzz...", intent: "sleepy" },
        { label: "えっ！？", intent: "驚き" },
        { label: "しょぼん", intent: "悲しみ" },
        { label: "ぷんぷん", intent: "怒り" },
        { label: "すき♡", intent: "愛情" },
        { label: "おはよう", intent: "挨拶" },
        { label: "ばいばい", intent: "別れ" }
      ].freeze

      def seed!
        brand = Linestamp::Brand.find_or_create_by!(slug: SLUG) do |b|
          b.character_name = CHARACTER_NAME
          b.series_name = SERIES_NAME
          b.description = DESCRIPTION
        end

        pack = brand.packs.find_or_create_by!(position: 1) do |p|
          p.series_theme = "ねむ犬 vol.1 日常編"
        end

        PACK_1_STAMPS.each_with_index do |stamp_cfg, idx|
          pack.stamps.find_or_create_by!(position: idx + 1) do |s|
            s.label = stamp_cfg[:label]
            s.intent = stamp_cfg[:intent]
          end
        end

        Rails.logger.info("[Linestamp::Seeders::Nemuinu] Seeded: brand=#{brand.id}, pack=#{pack.id}, stamps=#{pack.stamps.count}")
        brand
      end
    end
  end
end
