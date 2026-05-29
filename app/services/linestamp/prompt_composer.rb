# frozen_string_literal: true

module Linestamp
  # DB-first のマスタ(CT / 属性軸)を参照して Brand / Pack / Stamp の3階層プロンプトを生成する。
  class PromptComposer
    DEFAULT_COMPOSITIONS = [
      "正面・無表情", "正面・うっすら笑顔", "正面・困り顔", "正面・真顔",
      "横向き立ち", "寝そべり", "座り(マグ抱え)", "椅子に座る",
      "両手合わせ", "サムズアップ", "軽く手を振る", "頬杖"
    ].freeze

    # --- Brand プロンプト (base_image 生成用) ---
    def compose_brand_prompt(brand)
      parts = brand.character_parts || {}
      fonts = brand.font_spec || {}
      demo_names    = brand.attribute_values_by_axis("demographic").pluck(:name).join(", ")
      setting_names = brand.attribute_values_by_axis("setting").pluck(:name).join(", ")
      cts           = brand.communication_themes.pluck(:name).join(" / ")

      parts_text = %w[eyes mouth ears body limbs tail collar].filter_map { |key|
        val = parts[key] || parts[key.to_sym]
        "- #{parts_label(key)}: #{val}" if val.present?
      }.join("\n        ")

      raw = <<~PROMPT
        あなたは LINE スタンプキャラクター仕様シートのデザイナーです。
        1枚の「キャラ仕様シート画像」を作ってください。これは今後の全パック・全スタンプの参照基準になります。

        【キャラクター定義(必須遵守の核)】
        #{brand.two_part_definition}

        【キャラの優先順位(必須遵守・スコア降順)】
        #{format_tone_axes(brand)}

        【ペルソナとシーン】
        送り手の想定: #{brand.persona_name}
        主な利用シーン: #{setting_names.presence || "汎用"}
        ターゲット世代: #{demo_names.presence || "指定なし"}
        扱うコミュニケーション: #{cts.presence || "未設定"}

        【キャラパーツ仕様(全構図で完全統一)】
        #{parts_text}
        - 体色: #{brand.primary_color}

        【フォント仕様(全パックで共通使用)】
        - 書体: #{fonts['primary']}
        - 文字色: #{fonts['color']}
        - フチ: #{fonts['outline']}

        【出力形式】
        1枚の画像内に以下を配置:
        ■ 上段:キャラ構図 12カット(3行 × 4列、すべて同じキャラの統一描写)
        #{format_compositions(brand)}
        ■ 下段:フォント基準 3パターンを横一列
          「おつかれ」「りょうかい」「OK」

        【背景】
        全領域を単色グリーン #{brand.background_color_for_gen}(後工程で透過するため必須)

        【厳守事項】
        - これは個別スタンプ集ではない。シリーズ一覧でもない。1体のキャラを12構図で描く仕様シートである
        - 全12構図で線の太さ・色・体型・目の形・首輪を一切変えない
        - 白背景禁止(白い体が透過処理で消える事故が過去にあり)
        - 文字は丁寧に正しい漢字で。崩れたら再生成
        - キャラの解釈を加えない(髪を描く・服を着せる・装飾を増やす等)
        - スタンプ風のフラットな塗り、影や立体感は最小限
      PROMPT
      tidy(raw)
    end

    # --- Pack プロンプト (sheet_image 生成用) ---
    def compose_pack_prompt(pack)
      brand  = pack.brand
      cts    = pack.communication_themes.pluck(:name).join(", ")
      scenes = (pack.usage_scenes || []).map { |s| setting_label(s) }.join(" / ")
      emos   = (pack.target_emotions || []).join(" / ")
      stamps_text = pack.stamps.order(:position).map { |s|
        ct_name = s.primary_communication_theme&.name || "未設定"
        "  ##{s.position} 「#{s.display_label}」 — #{s.situation}(主テーマ: #{ct_name})"
      }.join("\n")

      raw = <<~PROMPT
        あなたは LINE スタンプシリーズ(8枚一覧)のデザイナーです。
        1枚の「シリーズ一覧画像」を作ってください。これがこのパック内のスタンプ品質の参照基準になります。

        【必ず参照する画像】
        Designer に添付する画像:
        - brand.base_image(キャラ仕様シート/12構図+3フォント基準)
        → このパック内のキャラ造形・線・色・首輪・フォントは、すべてこの基準と完全一致させること

        【シリーズコンセプト】
        シリーズ名: #{pack.series_theme}
        世界観: #{pack.world_view.presence || "未設定"}
        Layer: #{pack.layer}

        【ペルソナと使われ方】
        送り手: #{brand.persona_name}
        送りたい感情: #{emos.presence || "未設定"}
        扱うコミュニケーション: #{cts.presence || "未設定"}
        想定利用シーン: #{scenes.presence || "未設定"}

        【採用しない要素(派生パックへの含み)】
        #{pack.excluded_elements.presence || "なし"}

        【8枚のスタンプ(2行 × 4列で1枚画像に配置)】
        #{stamps_text}

        【厳守事項】
        - キャラ仕様は brand.base_image と完全一致(線・色・体型・目・首輪)
        - 文字は brand.base_image のフォント基準と完全一致(書体・色・フチ)
        - 各コマは正方形、余白を統一
        - 背景は単色グリーン #{brand.background_color_for_gen}
        - 漢字は丁寧に。崩れたら再生成、ひらがな逃げ禁止
        - 8コマ全てで「キャラの揺れ」を絶対禁止(顔・線・首輪が変わらない)
        - 1枚画像内で完結させる(個別書き出しは別工程)
      PROMPT
      tidy(raw)
    end

    # 後方互換: 旧名メソッド
    alias_method :compose_pack_sheet_prompt, :compose_pack_prompt

    # --- Stamp プロンプト (raw_image 生成用) ---
    def compose_stamp_prompt(stamp)
      pack  = stamp.pack
      brand = pack.brand
      ct    = stamp.primary_communication_theme
      spec  = pack.effective_image_spec
      kw    = stamp.search_keywords || []

      raw = <<~PROMPT
        あなたは個別 LINE スタンプのデザイナーです。
        1枚の正方形スタンプを作ってください。

        【必ず参照する画像(両方とも Designer に添付)】
        1. brand.base_image — キャラ仕様シート(揺れ防止)
        2. pack.sheet_image — このシリーズの8枚一覧(パック内一貫性)

        両方の画像に完全一致するキャラ・色・線・フォントで描いてください。

        【スタンプ ##{stamp.position}】
        - 文言: 「#{stamp.display_label}」
        - 主テーマ: #{ct&.name || "未設定"}
        #{ct&.description.present? ? "  (#{ct.description})" : ""}
        - シチュエーション: #{stamp.situation}
        - ポーズ: #{stamp.pose_spec}
        - 小道具: #{stamp.props}
        - 送り手の意図: #{stamp.intent}
        - 利用シーン: #{stamp.usage_scene}
        - コミュニケーション代替価値: #{stamp.communication_purpose}
        #{kw.present? ? "- 検索キーワード: #{kw.join(' / ')}" : ""}

        【キャラ仕様】
        brand.base_image と完全一致。線・色・体型・目・首輪・しっぽを一切変えない。
        新しい解釈・装飾・服装を加えない。

        【文字仕様】
        - 文言「#{stamp.display_label}」を中央上部に配置
        - 書体・色・フチは brand.base_image のフォント基準と完全一致
        - 漢字は丁寧に正しく描く。崩れたら再生成、ひらがなに逃げない

        【画像規格】
        - 仕上がりサイズ目安: #{spec&.width || 370}×#{spec&.height || 320}(後工程でトリム)
        - 背景: 単色グリーン #{brand.background_color_for_gen}(全領域)
        - キャラはスタンプ領域の 80% 以上を占める
        - 1画像に1スタンプのみ
      PROMPT
      tidy(raw)
    end

    private

    def tidy(text)
      text.gsub(/[ \t]+\n/, "\n").gsub(/\n{3,}/, "\n\n").strip
    end

    def format_tone_axes(brand)
      axes = brand.tone_axes
      if axes.present?
        axes.sort_by { |_key, value| -value.to_f }.each_with_index.map { |(key, value), index|
          "#{index + 1}. #{tone_label(key)} #{(value.to_f * 100).round}%"
        }.join("\n        ")
      else
        names = brand.attribute_values_by_axis("tone").pluck(:name)
        names.any? ? names.join(" × ") : "指定なし"
      end
    end

    def format_compositions(brand)
      raw = brand.respond_to?(:base_compositions) ? brand.base_compositions : nil
      list =
        if raw.present?
          raw.map { |composition|
            composition.is_a?(Hash) ? (composition["label"] || composition[:label]) : composition
          }.compact
        else
          DEFAULT_COMPOSITIONS
        end
      list = DEFAULT_COMPOSITIONS if list.empty?
      list.each_slice(4).map { |row| "  #{row.join(' / ')}" }.join("\n")
    end

    def tone_label(slug)
      Linestamp::AttributeValue.for_axis("tone").find_by(slug: slug.to_s)&.name || slug.to_s
    end

    def setting_label(slug)
      Linestamp::AttributeValue.for_axis("setting").find_by(slug: slug.to_s)&.name || slug.to_s
    end

    def parts_label(key)
      {
        "eyes" => "目", "mouth" => "口", "ears" => "耳",
        "body" => "体", "limbs" => "手足", "tail" => "しっぽ", "collar" => "首回り"
      }[key.to_s] || key.to_s
    end
  end
end
