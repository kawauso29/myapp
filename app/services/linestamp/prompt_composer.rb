module Linestamp
  class PromptComposer
    def compose_brand_prompt(brand)
      parts = brand.character_parts || {}
      fonts = brand.font_spec || {}
      tone_text = (brand.tone_axes || {}).map { |k, v| "#{k}: #{(v.to_f * 100).round}%" }.join(", ")

      parts_text = %w[eyes mouth ears body limbs tail collar].filter_map { |key|
        val = parts[key]
        "- #{I18n.t("linestamp.parts.#{key}", default: key.titleize)}: #{val}" if val.present?
      }.join("\n")

      <<~PROMPT.strip
        あなたはLINEスタンプキャラクターのキャラ仕様シートを描くデザイナーです。

        ## キャラクター定義
        #{brand.two_part_definition}

        ## キャラパーツ仕様(必須遵守)
        #{parts_text}

        ## フォント仕様
        - 基本: #{fonts['primary']}
        - 色: #{fonts['color']}
        - フチ: #{fonts['outline']}

        ## トーン
        #{tone_text}

        ## 出力形式(極めて重要)
        1枚のキャラ仕様シートを生成してください。以下の構成:
        - **キャラ構図 12カット**(3行 × 4列 のグリッド配置)
          * 正面・無表情、正面・眠そう、正面・微笑、正面・困り顔
          * 正面・疲れ、正面・気まずさ、正面・ねぎらい、正面・真剣
          * 寝そべり、座り(マグ抱え)、両手合わせ、サムズアップ
        - **フォント基準 3パターン**を画像下部に配置
          * 「おつかれ」「りょうかい」「OK」
          * 全パックで共通使用する文字スタイル
        - **背景**: 単色グリーン(#{brand.background_color_for_gen})
        - すべてのコマで線・色・体型・首輪・目を完全に統一

        この画像は今後の全パック・全スタンプの参照基準として使われます。
      PROMPT
    end

    def compose_pack_sheet_prompt(pack)
      brand = pack.brand
      spec = pack.effective_image_spec
      stamps_text = pack.stamps.order(:position).map { |s|
        "##{s.position} 「#{s.display_label}」 - #{s.situation} (意図: #{s.intent}, 小道具: #{s.props})"
      }.join("\n")

      <<~PROMPT.strip
        あなたはLINEスタンプシリーズのデザイナーです。

        ## 必ず参照する画像
        1. brand.base_image — キャラ仕様シート(12構図 + 3フォント基準)
           → Designer に「参照画像」として添付すること
        2. このシリーズの世界観 → #{pack.world_view}

        ## シリーズテーマ
        #{pack.series_theme} (Layer: #{pack.layer})

        ## 想定利用シーン
        #{(pack.usage_scenes || []).join(', ')}

        ## ターゲット感情
        #{(pack.target_emotions || []).join(', ')}

        ## 採用しない要素(派生パックへの含み)
        #{pack.excluded_elements}

        ## 出力形式
        8枚スタンプの一覧シート(2行 × 4列):
        #{stamps_text}

        ## キャラ仕様(brand.base_image と完全一致)
        線・色・体型・目・首輪を一切変えないこと。
        顔のサイズ・線の太さ・パステル色味も基準シート通り。

        ## 文字スタイル(brand.base_image のフォント基準と完全一致)
        太丸・濃ブラウン・太い白フチ(基準シート下部の「おつかれ/りょうかい/OK」と同じ)

        ## 背景
        単色グリーン #{brand.background_color_for_gen}

        ## サイズ
        各コマは正方形、最終的に LINE 規格 #{spec&.width || 370}×#{spec&.height || 320} で書き出される前提
      PROMPT
    end

    def compose_stamp_prompt(stamp)
      pack = stamp.pack
      brand = pack.brand
      spec = pack.effective_image_spec

      <<~PROMPT.strip
        あなたは個別LINEスタンプのデザイナーです。

        ## 必ず参照する画像(両方添付すること)
        1. brand.base_image — キャラ仕様シート(揺れ防止のため)
        2. pack.sheet_image — 該当パックの8枚一覧シート(パック内一貫性のため)

        Designer ではこの2枚を参照画像として添付してください。

        ## スタンプ ##{stamp.position}
        - ラベル: 「#{stamp.display_label}」
        - 想定シーン: #{stamp.usage_scene}
        - シチュエーション: #{stamp.situation}
        - 送信意図: #{stamp.intent}
        - コミュニケーション代替価値: #{stamp.communication_purpose}
        - ポーズ: #{stamp.pose_spec}
        - 小道具: #{stamp.props}
        - 検索キーワード: #{(stamp.search_keywords || []).join(', ')}

        ## キャラ仕様(brand.base_image と完全一致)
        線・色・体型・目・首輪を一切変えないこと。
        新しい解釈を加えない。

        ## 文字仕様
        - 文言: 「#{stamp.display_label}」を中央上部に配置
        - スタイル: brand.base_image のフォント基準と完全一致
        - 漢字は正しく丁寧に。崩れたら再生成。ひらがなに逃げない

        ## 画像規格
        - サイズ: #{spec&.width || 370}×#{spec&.height || 320}
        - 背景: 単色グリーン(#{brand.background_color_for_gen})
        - 1画像1スタンプ
        - キャラがスタンプ領域の80%以上
      PROMPT
    end
  end
end
