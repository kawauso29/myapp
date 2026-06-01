#!/usr/bin/env bash
# =============================================================================
# C案: ブランド差別化の6軸を追補する。cleanup_b.sh の「後」に流す前提。
#   - リポジトリのルートで実行する: bash cleanup_c.sh
#
# 背景:
#   「またかわいい動物の量産」を防ぐため、Research の brand_idea 起点 +
#   identity_axes の2段で差別化する方針(08_PLANNING_GUIDE / CLAUDE.md)。
#   その identity_axes を、ブランドクリエータのプロ視点で不足していた6軸に拡張する。
#
# 実装する6軸:
#   #1 シルエット/頭身    : 黒塗りシルエットでも識別できる全体輪郭(最重要・新規)
#   #2 ネーミング(由来)   : 名前の由来・読みを構造化(character_name は既存列、由来が無かった)
#   #3 欲求と弱点         : 何を求め・何が苦手か(behavior より一段深い動機)
#   #4 シグネチャーカラー : このブランドが「持つ」色の主張(competitor と被らせない)
#   #5 衝突チェック       : 既存ブランドとの被りを検出する rake タスク(実ロジック)
#   #6 サムネ識別性       : 240×240 / 96×74 に縮小しても識別できること(プロンプト条項)
#
# 持たせ方:
#   #1〜#4, #6 は linestamp_brands.identity_axes(jsonb)へのキー追加で済む
#   → DB migration 不要(PromptComposer が nil ガード付きで読む既存パターンを踏襲)。
#   #5 のみ lib/tasks の rake タスク(実ロジック)として追加する。
#
# 注意:
#   本スクリプトは prompt_composer.rb と brand_template.rb を「全置換」する。
#   cleanup_b.sh が入れた変更(research_background 反映 等)を内包した最終形を書き出すため、
#   必ず cleanup_b.sh の後に実行すること。
# =============================================================================
set -euo pipefail

if [ ! -f Gemfile ] || [ ! -f config/application.rb ]; then
  echo "ERROR: リポジトリのルートで実行してください (Gemfile が見つかりません)" >&2
  exit 1
fi

if [ ! -f app/services/linestamp/prompt_composer.rb ]; then
  echo "ERROR: prompt_composer.rb が見つかりません。先に cleanup_b.sh を実行してください。" >&2
  exit 1
fi

echo "==> 1/5 PromptComposer を全置換 (B案の research_background を内包 + 差別化6軸を反映)"
cat > app/services/linestamp/prompt_composer.rb <<'RUBY'
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

    # ブランド識別軸(他と混同されない核)。表示順 = プロンプトでの提示順。
    #   silhouette / name_origin / signature_color / desire_weakness は C案で追加。
    IDENTITY_KEYS = {
      "silhouette"      => "シルエット・頭身(黒塗りでも識別できる全体輪郭)",
      "name_origin"     => "名前の由来・読み",
      "signature"       => "シグネチャー(必ず出す識別要素)",
      "signature_color" => "占有する色(競合と被らない色の主張)",
      "desire_weakness" => "欲求と弱点(何を求め・何が苦手か)",
      "voice"           => "語り口・トーン",
      "behavior"        => "ふるまい・癖"
    }.freeze

    # #6 サムネ識別性: 全階層の厳守事項に共通注入する条項。
    THUMBNAIL_NOTE = "主役サムネ 240×240 / タブ 96×74 に縮小しても、シルエットと占有色だけでこのキャラだと一目で分かること。細部の描き込みより輪郭の明快さを優先する。"

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
        - #{THUMBNAIL_NOTE}
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
        - #{THUMBNAIL_NOTE}
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
        - #{THUMBNAIL_NOTE}
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

    # Pack / Stamp プロンプトに継承する「視覚的に間違えられない核」。
    #   silhouette / signature_color は C案で追加(パック内のスタンプ間一貫性に効く)。
    def identity_carry(brand)
      axes = brand.identity_axes || {}
      pairs = {
        "silhouette"      => "シルエット",
        "signature"       => "シグネチャー",
        "signature_color" => "占有色",
        "voice"           => "語り口"
      }.filter_map { |key, label|
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
RUBY

echo "==> 2/5 brand_template.rb を全置換 (identity_axes を7軸に拡張・例値を充填)"
cat > db/seeds/linestamp/imports/_templates/brand_template.rb <<'RUBY'
# frozen_string_literal: true

# Brand + 初回 Pack(8 stamps) を 1 ファイルで投入する Importer DSL の雛形。
# File: db/seeds/linestamp/imports/pending/{YYYY-MM-DD-HHMMSS}_brand_{slug}.rb
#
# 注意:
#   - 1 ブランド = 1 ファイル = Brand + 初回 Pack(stamps 8 枚) を必ず同梱する。
#   - 核フィールド(two_part_definition / character_parts / font_spec / tone_axes / target_axes)は必須。
#   - background_color_for_gen は書かない(モデルが #3CB371 に固定する)。
#   - 世界観カラーは primary_color に入れる。
#   - プロンプト系カラム(brand_prompt / sheet_prompt / stamp.prompt) は書かない。
#     レコード作成時の after_commit で自動合成される。
#   - 各 stamp の primary_communication_theme は、Brand に紐づけた slug を使う。
#   - 追加で Pack を増やしたい場合は pack_template.rb を使って別ファイルで投入する。
#   - identity_axes は「またかわいい動物量産」を防ぐ差別化の核。投入前に
#     `bin/rails linestamp:brand_collision` で既存ブランドとの被りを必ず検査する。

Linestamp::Importer.run(seed_id: "REPLACE_WITH_UNIQUE_ID") do
  # --- Brand 本体 ---
  brand = upsert_brand!(
    slug: "my_brand",
    character_name: "キャラ名",
    series_name: "シリーズ名",
    persona_name: "ペルソナ名",
    concept: "ブランドコンセプト",
    target_audience: "ターゲット層の説明",
    description: "ブランド説明",
    primary_color: "#F6E7D8",
    two_part_definition: "キャラ名は「ただかわいい動物」ではない。キャラ名は、相手の気持ちを軽く受け止める、少し眠そうな相棒である。",
    character_parts: {
      eyes: "半目で黒目は小さめ、眠そうだが不機嫌ではない",
      mouth: "小さな横線、笑う時も口角だけ少し上がる",
      ears: "丸く短い耳、左右対称",
      body: "2頭身の丸い体、手足は短い",
      limbs: "短い手足、指は描き込まない",
      tail: "短く丸いしっぽ",
      collar: "細い首輪と小さな丸いタグ"
    },
    font_spec: {
      primary: "丸ゴシック太め",
      color: "#4B3426",
      outline: "white_thick_4px"
    },
    tone_axes: { gentle: 0.95, cute: 0.7, funny: 0.3 },
    target_axes: {
      age: %w[age_20s age_30s],
      gender: %w[unisex],
      occupation: %w[office_worker]
    },
    identity_axes: {
      # 他ブランドと絶対に混同されない核。使わない軸は空文字で残す(プロンプトには出ない)。
      # 投入前に `bin/rails linestamp:brand_collision` で既存ブランドとの被りを検査すること。
      silhouette:      "2頭身・丸い輪郭・短い手足。黒塗りシルエットでも『丸い相棒』と分かる", # #1 最重要: 黒塗りで識別できる全体形
      name_origin:     "『モカ』= マグのコーヒー由来。読み: もか",                          # #2 名前の由来・読み
      signature:       "首元の小さな丸いタグ(全構図で必ず描く)",                           # シグネチャー(必ず出す要素)
      signature_color: "くすみベージュ #F6E7D8 を主役色として占有(競合の白/原色と差別化)",    # #4 占有色の主張
      desire_weakness: "求める: 静かな安心 / 苦手: 急かされること・大きな音",                # #3 欲求と弱点
      voice:           "断定しない・語尾がやわらかい",                                    # 語り口
      behavior:        "考えるときマグカップを抱える"                                     # ふるまい・癖
    },
    base_compositions: [
      "正面・無表情",
      "正面・うっすら笑顔",
      "正面・困り顔",
      "正面・真顔",
      "横向き立ち",
      "寝そべり",
      "座り(マグ抱え)",
      "椅子に座る",
      "両手合わせ",
      "サムズアップ",
      "軽く手を振る",
      "頬杖"
    ]
  )

  attach_communication_themes!(brand, %w[
    greeting_morning
    gratitude
    appreciation_for_effort
    encouragement
    quick_answer
    need_break
    apology
    agreement
  ])

  attach_attribute_values!(brand, {
    tone: %w[gentle cute],
    motif: %w[animal],
    demographic: %w[age_20s age_30s unisex],
    setting: %w[home remote_work office]
  })

  # --- 初回 Pack(必ず 8 stamps) ---
  create_pack!(
    brand: brand,
    slug: "pack_001",
    series_theme: "シリーズのテーマ(例: 在宅ワークの日常)",
    position: 1,
    layer: "core_work",
    purchase_unit_size: 8,
    world_view: "シリーズの世界観(任意)",
    usage_scenes: %w[remote_work home],
    target_emotions: %w[安心 共感 労り],
    communication_themes: %w[greeting_morning gratitude],
    attributes: {
      tone: %w[gentle],
      setting: %w[remote_work home]
    },
    stamps: [
      {
        label: "おはよう",
        primary_communication_theme: "greeting_morning",
        communication_themes: %w[greeting_morning],
        attributes: { tone: %w[gentle], setting: %w[remote_work] },
        situation: "1日の始まりの挨拶",
        intent: "やわらかく1日を始める",
        pose_spec: "正面・うっすら笑顔・軽く手を振る",
        props: "なし",
        usage_scene: "朝の業務開始連絡",
        communication_purpose: "返信負担を増やさず温度を伝える",
        search_keywords: %w[朝 挨拶 おはよう 業務開始]
      },
      {
        label: "おつかれ",
        primary_communication_theme: "appreciation_for_effort",
        communication_themes: %w[appreciation_for_effort],
        attributes: { tone: %w[gentle], setting: %w[office remote_work] },
        situation: "業務終了時のねぎらい",
        intent: "相手の頑張りを肯定する",
        pose_spec: "正面・微笑み",
        props: "なし",
        usage_scene: "業務終了 / 退勤時",
        communication_purpose: "短文でねぎらいを伝える",
        search_keywords: %w[おつかれ 退勤 ねぎらい 仕事]
      },
      {
        label: "ありがとう",
        primary_communication_theme: "gratitude",
        communication_themes: %w[gratitude],
        attributes: { tone: %w[gentle], setting: %w[office home] },
        situation: "助けてもらったとき",
        intent: "感謝を素直に伝える",
        pose_spec: "両手を合わせるおじぎ",
        props: "なし",
        usage_scene: "相手の協力を受けたとき",
        communication_purpose: "形式的にならない感謝表現",
        search_keywords: %w[ありがとう 感謝 助かった お礼]
      },
      {
        label: "了解",
        primary_communication_theme: "quick_answer",
        communication_themes: %w[quick_answer],
        attributes: { tone: %w[gentle], setting: %w[office] },
        situation: "依頼や連絡を受けたとき",
        intent: "短く受領を伝える",
        pose_spec: "サムズアップ",
        props: "なし",
        usage_scene: "業務チャット即レス",
        communication_purpose: "返信負担を最小化",
        search_keywords: %w[了解 返事 OK 確認]
      },
      {
        label: "わかる",
        primary_communication_theme: "agreement",
        communication_themes: %w[agreement],
        attributes: { tone: %w[gentle], setting: %w[home with_friends] },
        situation: "相手の話に共感したいとき",
        intent: "共感を即座に返す",
        pose_spec: "頷き",
        props: "なし",
        usage_scene: "雑談・愚痴の聞き役",
        communication_purpose: "言葉にしづらい共感を伝える",
        search_keywords: %w[わかる 共感 それな 相槌]
      },
      {
        label: "ごめん",
        primary_communication_theme: "apology",
        communication_themes: %w[apology],
        attributes: { tone: %w[gentle], setting: %w[office home] },
        situation: "ミスや遅延を詫びるとき",
        intent: "重くなりすぎず詫びる",
        pose_spec: "頭をかく",
        props: "なし",
        usage_scene: "軽い謝罪",
        communication_purpose: "謝罪のハードルを下げる",
        search_keywords: %w[ごめん 謝罪 遅延 ミス]
      },
      {
        label: "ちょっと休憩",
        primary_communication_theme: "need_break",
        communication_themes: %w[need_break],
        attributes: { tone: %w[gentle], setting: %w[remote_work home] },
        situation: "離席や休憩を伝えるとき",
        intent: "離席を角を立てず共有",
        pose_spec: "マグカップを抱える",
        props: "マグカップ",
        usage_scene: "中抜け・離席連絡",
        communication_purpose: "状況共有を簡潔に",
        search_keywords: %w[休憩 離席 中抜け コーヒー]
      },
      {
        label: "がんばろう",
        primary_communication_theme: "encouragement",
        communication_themes: %w[encouragement],
        attributes: { tone: %w[gentle], setting: %w[office remote_work] },
        situation: "相手を励ましたいとき",
        intent: "前向きに背中を押す",
        pose_spec: "両手で小さくガッツポーズ",
        props: "なし",
        usage_scene: "週明け / 大事な場面の前",
        communication_purpose: "押しつけがましくない励まし",
        search_keywords: %w[がんばろう 応援 週明け 励まし]
      }
    ]
  )
end
RUBY

echo "==> 3/5 (#5) ブランド衝突チェック rake タスクを追加"
cat > lib/tasks/linestamp_brand_collision.rake <<'RUBY'
# frozen_string_literal: true

namespace :linestamp do
  desc "ブランド間で識別軸(シルエット/シグネチャー/占有色)が被っていないか検査する。被りは「またかわいい動物量産」の兆候。"
  task brand_collision: :environment do
    axes = {
      "silhouette"      => "シルエット/頭身",
      "signature"       => "シグネチャー(必ず出す識別要素)",
      "signature_color" => "占有色"
    }

    normalize = ->(text) {
      text.to_s
          .unicode_normalize(:nfkc)
          .downcase
          .gsub(/[[:space:]]/, "")
          .gsub(/[、。,.\/()()「」\-_]/, "")
    }

    brands = Linestamp::Brand.order(:id).to_a
    if brands.size < 2
      puts "ブランドが #{brands.size} 件のみ。衝突検査には2件以上必要です。"
      next
    end

    puts "=== Linestamp ブランド識別軸 衝突レポート (#{brands.size} brands) ==="
    collisions = 0

    axes.each do |key, label|
      rows = brands.map { |b|
        raw = (b.identity_axes || {})[key].to_s.strip
        { brand: b, raw: raw, norm: normalize.call(raw) }
      }

      hits = []
      rows.each_with_index do |a, i|
        next if a[:norm].blank?

        rows[(i + 1)..].each do |c|
          next if c[:norm].blank?

          same = a[:norm] == c[:norm]
          contained = a[:norm].include?(c[:norm]) || c[:norm].include?(a[:norm])
          hits << [a, c, same ? "完全一致" : "包含"] if same || contained
        end
      end

      next if hits.empty?

      puts "\n■ #{label}（#{key}）の被り:"
      hits.each do |a, c, kind|
        collisions += 1
        puts "  [#{kind}] #{a[:brand].character_name}: \"#{a[:raw]}\""
        puts "          ↕ #{c[:brand].character_name}: \"#{c[:raw]}\""
      end
    end

    # primary_color(列)の完全一致も占有色の被りとして検出する。
    color_groups = brands.group_by { |b| b.primary_color.to_s.downcase.strip }
                         .reject { |hex, _| hex.blank? }
    color_groups.each do |hex, list|
      next if list.size < 2

      collisions += 1
      puts "\n■ primary_color #{hex} を複数ブランドが使用:"
      list.each { |b| puts "  - #{b.character_name}" }
    end

    puts "\n=== 検出: #{collisions} 件の被り ==="
    if collisions.zero?
      puts "識別軸の衝突なし。各ブランドは黒塗りシルエット・シグネチャー・占有色で区別可能です。"
    else
      puts "⚠ 上記を解消してから新ブランドを増やすこと(またかわいい動物化の防止)。"
    end
  end
end
RUBY

echo "==> 4/5 PLANNING_GUIDE に差別化6軸の追補ドキュメントを追記"
cat >> docs/linestamp/08_PLANNING_GUIDE.md <<'MD'

## 追補: ブランド差別化の identity_axes 6軸(C案)

「またかわいい動物の量産」を防ぐため、`identity_axes`(jsonb)に以下の軸を持たせる。
すべて空文字なら従来どおりプロンプトに出ない(任意)。ただし新規ブランドは
最低でも `silhouette` / `signature` / `signature_color` を埋めること。

| キー | 役割 | 例 |
|---|---|---|
| `silhouette` | **#1 最重要**。黒塗りシルエット・頭身でも識別できる全体輪郭 | "2頭身・丸い輪郭・短い手足" |
| `name_origin` | #2 名前の由来・読み(character_name を補強) | "『モカ』= マグのコーヒー由来。読み: もか" |
| `signature` | 必ず全構図で描く識別要素 | "首元の小さな丸いタグ" |
| `signature_color` | #4 競合と被らせず占有する色の主張 | "くすみベージュ #F6E7D8 を占有" |
| `desire_weakness` | #3 何を求め・何が苦手か(behavior より深い動機) | "求める: 静かな安心 / 苦手: 急かされること" |
| `voice` | 語り口・トーン | "断定しない・語尾がやわらかい" |
| `behavior` | ふるまい・癖 | "考えるときマグカップを抱える" |

- `silhouette` / `signature` / `signature_color` / `voice` は Pack / Stamp プロンプトにも継承され、パック内のスタンプ間ブレを抑える。
- **#6 サムネ識別性**: 全階層のプロンプト厳守事項に「240×240 / 96×74 に縮小しても識別できること」を自動注入済み(`PromptComposer::THUMBNAIL_NOTE`)。
- **#5 衝突チェック**: 投入前に必ず実行する。

```
bin/rails linestamp:brand_collision
```

既存ブランドと `silhouette` / `signature` / `signature_color` / `primary_color` が被っていないかをレポートする。被りが出たら解消してから新ブランドを増やす。
MD

echo "==> 5/5 CLAUDE.md に変更記録を追記"
cat >> CLAUDE.md <<'MD'

## 変更記録: C案 — ブランド差別化6軸(identity_axes 拡張 + 衝突チェック)

cleanup_b.sh の後に適用。「またかわいい動物量産」防止を Research 起点 + identity_axes の2段で強化する続き。

- **#1 シルエット/頭身**: `identity_axes.silhouette` を新設。黒塗りシルエットでも識別できる全体輪郭を必須化(最重要)。
- **#2 ネーミング(由来)**: `identity_axes.name_origin` を新設。`character_name`(列)に読み・由来を構造的に補強。
- **#3 欲求と弱点**: `identity_axes.desire_weakness` を新設。`behavior`(癖)より一段深い動機を持たせる。
- **#4 シグネチャーカラー占有**: `identity_axes.signature_color` を新設。競合と被らせない色の主張。
- **#5 衝突チェック**: `bin/rails linestamp:brand_collision`(`lib/tasks/linestamp_brand_collision.rake`)を追加。既存ブランドと `silhouette` / `signature` / `signature_color` / `primary_color` の被りを検出する実ロジック。新ブランド投入前に必ず実行。
- **#6 サムネ識別性**: `PromptComposer::THUMBNAIL_NOTE` を Brand / Pack / Stamp の全プロンプト厳守事項に注入(240×240 / 96×74 で識別できること)。
- いずれも `linestamp_brands.identity_axes`(jsonb)へのキー追加で済むため **DB migration 不要**。PromptComposer は既存の nil ガードで読む(`IDENTITY_KEYS` / `identity_carry`)。
- `brand_template.rb` の identity_axes を7軸に拡張し例値を充填。`08_PLANNING_GUIDE.md` に6軸の表と衝突チェック手順を追記。
- 注: PromptComposer と brand_template.rb は cleanup_b.sh の変更(research_background 反映 等)を内包した最終形で全置換している。必ず cleanup_b.sh の後に実行すること。
MD

echo
echo "============================================================"
echo " identity_axes の新キーがコードに通っているか確認:"
grep -n -E 'silhouette|name_origin|signature_color|desire_weakness|THUMBNAIL_NOTE' \
  app/services/linestamp/prompt_composer.rb | head -20
echo "------------------------------------------------------------"
echo " 衝突チェック rake タスク:"
grep -n 'task brand_collision' lib/tasks/linestamp_brand_collision.rake
echo "------------------------------------------------------------"
echo " C案 追補完了。次の確認を推奨:"
echo "    bin/rubocop"
echo "    bundle exec rspec"
echo "    bin/rails linestamp:brand_collision   # 既存ブランドの被り検査"
echo "    git diff --stat"
echo "============================================================"
