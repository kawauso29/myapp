# frozen_string_literal: true

module Linestamp
  # DB-first のマスタ(CT / 属性軸)を参照して Brand / Pack / Stamp の3階層プロンプトを生成する。
  class PromptComposer
    DEFAULT_COMPOSITIONS = [
      "正面・無表情", "正面・うっすら笑顔", "正面・困り顔", "正面・真顔",
      "横向き立ち", "寝そべり", "座り(マグ抱え)", "椅子に座る",
      "両手合わせ", "サムズアップ", "軽く手を振る", "頬杖"
    ].freeze
    PART_AXES = %w[eyes mouth ears body limbs tail collar].freeze
    IDENTITY_KEYS = {
      "signature" => "シグネチャー(必ず出す識別要素)",
      "voice" => "語り口・トーン",
      "behavior" => "ふるまい・癖"
    }.freeze

    # --- Brand プロンプト (base_image 生成用) ---
    def compose_brand_prompt(brand)
      parts = brand.character_parts || {}
      fonts = brand.font_spec || {}
      demo_names    = brand.attribute_values_by_axis("demographic").pluck(:name).join(", ")
      setting_names = brand.attribute_values_by_axis("setting").pluck(:name).join(", ")
      cts           = brand.communication_themes.pluck(:name).join(" / ")
      identity_block = identity_lines(brand)
      research_block = research_background(brand)

      parts_text = PART_AXES.filter_map { |key|
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

        #{research_block.present? ? "#{research_block}\n" : ""}
        #{identity_block.present? ? "【ブランド識別軸(他と間違えられない核)】\n        #{identity_block}\n" : ""}
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
        - 全12構図で線の太さ・色・塗り・体型を一切変えない#{consistency_clause(brand)}
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
      identity = identity_carry(brand)
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
        → このパック内のキャラ造形・線・色・塗り・フォントは、すべてこの基準と完全一致させること#{consistency_clause(brand)}

        【シリーズコンセプト】
        シリーズ名: #{pack.series_theme}
        世界観: #{pack.world_view.presence || "未設定"}
        Layer: #{pack.layer}

        【ペルソナと使われ方】
        送り手: #{brand.persona_name}
        送りたい感情: #{emos.presence || "未設定"}
        扱うコミュニケーション: #{cts.presence || "未設定"}
        想定利用シーン: #{scenes.presence || "未設定"}
        #{identity.present? ? identity : ""}

        【採用しない要素(派生パックへの含み)】
        #{pack.excluded_elements.presence || "なし"}

        【8枚のスタンプ(2行 × 4列で1枚画像に配置)】
        #{stamps_text}

        【厳守事項】
        - キャラ仕様は brand.base_image と完全一致（線・色・体型・塗り）#{consistency_clause(brand)}
        - 文字は brand.base_image のフォント基準と完全一致(書体・色・フチ)
        - 各コマは正方形、余白を統一
        - 背景は単色グリーン #{brand.background_color_for_gen}
        - 漢字は丁寧に。崩れたら再生成、ひらがな逃げ禁止
        - 8コマ全てで「キャラの揺れ」を絶対禁止（顔・線・塗りが変わらない）#{consistency_clause(brand)}
        - 1枚画像内で完結させる(個別書き出しは別工程)
      PROMPT
      tidy(raw)
    end

    # 後方互換: 旧名メソッド
    alias_method :compose_pack_sheet_prompt, :compose_pack_prompt

    # --- Stamp プロンプト (個別スタンプ画像 生成用) ---
    def compose_stamp_prompt(stamp)
      pack  = stamp.pack
      brand = pack.brand
      ct    = stamp.primary_communication_theme
      spec  = pack.effective_image_spec
      kw    = stamp.search_keywords || []
      identity = identity_carry(brand)

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
        #{identity.present? ? identity : ""}
        brand.base_image と完全一致。線・色・体型・塗りを一切変えない#{consistency_clause(brand)}。
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

    # Research 由来のブランド案メモ(複数候補を含むテキスト)を、企画背景の参考情報として差し込む。
    # research は optional belongs_to なので未紐付け / 空なら何も足さない(従来挙動を完全維持)。
    def research_background(brand)
      ideas = brand.research&.brand_ideas
      return "" if ideas.blank?

      <<~TEXT.strip
        【企画の背景(Research由来・参考情報)】
        このブランドが派生した市場調査のブランド案メモ(複数候補を含む。下記は狙いを理解するための背景であり、画像に文字や複数キャラを描き込む指示ではない):
        #{ideas.to_s.strip}
        ※この調査から1案に絞り込んでこのキャラは設計されている。「ただかわいい動物」の量産にせず、上の狙いと下の識別軸を反映した1体だけを描くこと。
      TEXT
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

    def identity_lines(brand)
      axes = brand.identity_axes || {}
      lines = IDENTITY_KEYS.filter_map { |key, label|
        val = axes[key] || axes[key.to_sym]
        "- #{label}: #{val}" if val.present?
      }
      lines << "- ブランドカラー(世界観): #{brand.primary_color}" if lines.any? && brand.primary_color.present?
      lines.join("\n        ")
    end

    def identity_carry(brand)
      axes = brand.identity_axes || {}
      pairs = { "signature" => "シグネチャー", "voice" => "語り口" }.filter_map { |key, label|
        val = axes[key] || axes[key.to_sym]
        "#{label}: #{val}" if val.present?
      }
      pairs.empty? ? "" : "識別の継承(brand 由来・厳守): #{pairs.join(' / ')}"
    end

    def consistency_parts(brand)
      parts = brand.character_parts || {}
      PART_AXES.filter_map { |key|
        parts_label(key) if (parts[key] || parts[key.to_sym]).present?
      }.join("・")
    end

    def consistency_clause(brand)
      parts = consistency_parts(brand)
      parts.present? ? "（固定部位: #{parts}）" : ""
    end

    def parts_label(key)
      {
        "eyes" => "目", "mouth" => "口", "ears" => "耳",
        "body" => "体", "limbs" => "手足", "tail" => "しっぽ", "collar" => "首回り"
      }[key.to_s] || key.to_s
    end
  end
end
