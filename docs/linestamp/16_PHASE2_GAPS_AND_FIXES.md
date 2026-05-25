# 16. Phase 2 — 実装ギャップ分析と修正設計

Phase 1(初版実装)を読んだ結果、設計の根幹が抜け落ちていることが判明。
このドキュメントは **Copilot Coding Agent に渡す Phase 2 修正 Issue** の元仕様。

---

## 致命的な欠落(優先度 ★★★)

### 1. 構造化情報が DB にない

設計の核は **「品質維持のためにブランド情報・調査軸を DB レコードで管理する」** ことだったが、
実装は全部 `text` カラム or `jsonb metadata` に詰め込んでいて構造化ゼロ。

#### Brand
| 必要項目 | 実装状態 |
|---|---|
| コンセプト(why) | ❌ `description` text に押し込み |
| ターゲット属性(年代/性別/職業/状況) | ❌ ない |
| 目的・背景 | ❌ ない |
| キャラパーツ別プロンプト(目・口・耳・体型・手足・首輪/タグ・しっぽ) | ❌ ない、`brand_prompt` text 一本 |
| フォント仕様(基本フォント・サブフォント・カラー・フチ仕様) | ❌ ない |
| トーン軸(ゆるい/かわいい/おもしろい/斬新/きっちり/...) | ❌ ない |
| 想定背景色(緑バック以外の世界観カラー) | ❌ ない |
| 二段定義「○○ではない、○○な△△」 | ❌ Brand_theme.md から欠落 |

#### Pack (= シリーズ)
| 必要項目 | 実装状態 |
|---|---|
| シリーズテーマ・世界観 | ❌ `title` text のみ |
| Layer (core_work / dream / weekend / seasonal) | ❌ ない |
| 想定利用シーン(オフィス/在宅/移動中/夜) | ❌ ない |
| ターゲット感情ニーズ | ❌ ない |
| 採用しない要素(派生パックへの含み) | ❌ ない |

#### Stamp
| 必要項目 | 実装状態 |
|---|---|
| 利用シーン詳細 | ❌ `text_overlay` のみ |
| コミュニケーション意図(申し訳なさ・ねぎらい・話題転換) | ❌ `emotion` で代用してるが粒度が違う |
| 検索キーワード | ❌ ない |
| 対話文脈での代替価値 | ❌ ない |
| ポーズ仕様・小道具 | ❌ ない |

#### Research
| 必要項目 | 実装状態 |
|---|---|
| ターゲット軸(年代/性別/職業) | ❌ ない |
| トーン軸(ゆるい/かわいい/...) | ❌ ない |
| 季節・イベント要因 | ❌ ない |
| 感情ニーズ抽出 | ❌ ない |
| 検索性ニーズ | ❌ ない |
| LINEで売れてるパターン分析 | ❌ ない |

→ **`research.body` text 一本に全部押し込まれていて、企画に流用できる構造化情報がない**

### 2. LINE規格設定がコード内ハードコード

`ChromaKeyProcessor` に 370×320 が定数で書かれているだけ。
**「規格マスタ」テーブルが無い**。

問題:
- LINEがアニメスタンプ(320×270)やビッグスタンプ(370×320)など複数形式を提供しているのに対応できない
- 過去事故メモにあった文字スタイル(太丸・濃ブラウン・太い白フチ)も画像規格の一部として管理されていない
- マージン10pxなどの値を変えたい時にコード変更が必要

### 3. PromptComposer の根本的欠陥

#### 3-A. base.png の 12構図×3フォント 仕様が抜け落ち

引継ぎの実物 `base.png` は:
- **12構図**(正面/横/座り/寝そべり/万歳/PC前 等)を 3×4 グリッドで配置
- **3フォントの基準文字**(おつかれ / りょうかい / OK)を下部に配置
- これがキャラ造形 + 文字スタイル の "**全パックで共有する基準書**"

実装 `compose_brand_prompt` は単に **「正面向きキャラクター」** を要求するだけ。
複数構図シート/フォント基準シートになる気配ゼロ。

#### 3-B. Pack sheet 生成時に brand.base_image を参照しない

`compose_pack_sheet_prompt` は `brand_prompt` という text しか読まない。
**`brand.base_image`(キャラ造形の基準書)を Designer に貼る指示が無い**。
→ 過去事故 #5「個別書き出しで顔・線・文字が揺れる」が再発する設計。

#### 3-C. Stamp 生成時に pack.sheet_image を参照しない

`compose_stamp_prompt` も `brand_prompt` の text のみ。
**`pack.sheet_image`(8枚一覧 = パック内一貫性の基準)を Designer に貼る指示が無い**。
→ 同上、揺れが再発。

#### 3-D. 「8〜40個のスタンプ」と曖昧

実装プロンプトに「8〜40個のスタンプで構成」と書かれている。
設計では **1パック = 8枚固定**(LINE申請の最小単位 = 8、24、40 のうち 8 を選定)。
manifest.yml は本来 8 枚を機械的に列挙する形だったが、実装の manifest.yml は8枚しかなくpositionすら無い

### 4. 管理画面で参照画像の同梱が無い

#### Stamp 詳細ページの致命的欠陥

- **brand.base_image を表示・ダウンロードする UI が無い**
- **pack.sheet_image を表示・ダウンロードする UI が無い**

これだと原田さんは Designer に貼るたびに別タブで pack 詳細を開いて画像保存しなければならない。
**「Designer に投げる際にユーザーが迷わないように同梱する」** が完全に未実現。

#### Pack 詳細でも brand.base_image が見えない

Pack ページから親 Brand の base_image を見るには Brand ページに戻る必要がある。
同じく "迷子" 設計。

### 5. brand_sources/nemuinu/* の seed が原仕様と乖離

| 引継ぎ仕様 | 実装の seed |
|---|---|
| 「ねむ犬は『かわいい犬』ではない」二段定義 | 「ゆるくて脱力系、でも愛おしい」(二段定義消失) |
| 細い半目(必須・丸目禁止) | 「半目」と一言だけ |
| 強制プロンプト本文 | ない |
| 表現レイヤー(Core/Work/Dream) | ない |
| 過去事故対策の記述 | ない |
| manifest situation 列 | ない、emotion + text のみ |

過去事故 #6「漢字崩れ対策」も完全に消失。LINEスタンプとして再現性のある品質を出せない。

### 6. ねむ犬の "プロジェクト精神" が再現できていない

引継ぎ事項で原田さんが大切にしていた要素:

| 引継ぎで重要だった事項 | 実装での扱い |
|---|---|
| 「眠そうだけどちゃんと仕事してる犬」 | "在宅ワーク" の文脈が消えている(vol.1 が "日常編" に汎化) |
| 在宅ワークパック(pack_001) | "ねむ犬 vol.1 日常編" に汎化、シーン情報なし |
| 8枚の文言「いま仕事中だよ/会議中です/...」 | 全部 emotion + 1文字単語に置換("やったー!" 等) |
| Phase分割(00/01/02 → 03 後出し) | この方針はあるが、PromptComposer に反映されていない |
| グリーンバック生成 | 守られているが、`#3CB371` ではなく `#00FF00` |

---

## 修正方針(優先度別)

### ★★★ Sprint A: スキーマ拡張(品質維持の基盤)

#### A-1. 新規 `linestamp_image_specs` テーブル(LINE規格マスタ)

```ruby
create_table :linestamp_image_specs do |t|
  t.string  :slug,    null: false             # "line_main_370x320" / "line_main_240x240" / "line_tab_96x74"
  t.string  :name,    null: false             # 「LINE メインスタンプ(横長)」
  t.integer :width,   null: false             # 370
  t.integer :height,  null: false             # 320
  t.integer :margin_px, default: 10
  t.string  :background, default: "transparent"  # 透過 / #00FF00 等
  t.jsonb   :font_specs, default: []          # [{name, color, outline, ...}]
  t.boolean :active, default: true
  t.timestamps
  t.index :slug, unique: true
end
```

初期 seed:
- `line_main_370x320` (メインスタンプ・横長)
- `line_main_240x240` (Phase 3 で対応予定)
- `line_tab_96x74` (Phase 3 で対応予定)

#### A-2. Brand に列を追加

```ruby
class AddStructuredFieldsToLinestampBrands < ActiveRecord::Migration[8.1]
  def change
    change_table :linestamp_brands do |t|
      t.text   :two_part_definition           # 「○○ではない、○○な△△」
      t.text   :concept                       # コンセプト本文
      t.text   :target_audience               # ターゲット属性(自由文)
      t.jsonb  :target_axes, default: {}      # {age: ["20s","30s"], gender: "any", occupation: "在宅勤務"}
      t.jsonb  :tone_axes,   default: {}      # {gentle: 0.9, cute: 0.8, funny: 0.3, ...} 0-1 スコア
      t.text   :purpose_background            # 目的・背景
      t.jsonb  :character_parts, default: {}  # 各パーツ別プロンプト
      t.jsonb  :font_spec, default: {}        # フォント仕様
      t.string :primary_color, default: "#FFFFFF"
      t.string :background_color_for_gen, default: "#00FF00"
    end
  end
end
```

`character_parts` の例:
```json
{
  "eyes": "細い半目(必須・丸目禁止)",
  "mouth": "小さい控えめな口",
  "ears": "垂れ耳",
  "body": "白い2頭身",
  "limbs": "短い手足",
  "tail": "小さなしっぽ",
  "collar": "水色首輪+タグ"
}
```

`tone_axes` の例(調査軸):
```json
{
  "gentle":    0.95,
  "cute":      0.7,
  "funny":     0.3,
  "innovative":0.2,
  "neat":      0.4,
  "warm":      0.8,
  "edgy":      0.0
}
```

#### A-3. Pack に列を追加

```ruby
class AddStructuredFieldsToLinestampPacks < ActiveRecord::Migration[8.1]
  def change
    change_table :linestamp_packs do |t|
      t.string :slug                           # "core_work_001" 等
      t.string :series_theme                   # 「在宅ワーク基本」
      t.string :layer                          # "core_work" / "dream" / "weekend" / "seasonal"
      t.text   :world_view                     # 世界観の説明
      t.jsonb  :usage_scenes, default: []      # ["朝の起床", "PC作業中", "会議直前", ...]
      t.jsonb  :target_emotions, default: []   # ["気まずさ", "ねぎらい", "ぼんやり"]
      t.text   :excluded_elements              # 「採用しない要素(派生パックへの含み)」
      t.references :image_spec, foreign_key: { to_table: :linestamp_image_specs }
    end
    add_index :linestamp_packs, [:brand_id, :slug], unique: true
  end
end
```

#### A-4. Stamp に列を追加

```ruby
class AddStructuredFieldsToLinestampStamps < ActiveRecord::Migration[8.1]
  def change
    change_table :linestamp_stamps do |t|
      t.string :label                       # 「いま仕事中だよ」(実装では text_overlay の役)
      t.text   :situation                   # シチュエーション説明
      t.text   :intent                      # 送信意図(申し訳なさ / ねぎらい / 話題転換)
      t.text   :usage_scene                 # 想定利用シーン
      t.jsonb  :search_keywords, default: []  # ["仕事", "PC", "在宅", "半目"]
      t.text   :communication_purpose       # コミュニケーション代替の意図
      t.text   :pose_spec                   # ポーズ仕様
      t.text   :props                       # 小道具(PC、マグカップ、ヘッドホン等)
    end
  end
end
```

#### A-5. Research に列を追加

```ruby
class AddStructuredFieldsToLinestampResearches < ActiveRecord::Migration[8.1]
  def change
    change_table :linestamp_researches do |t|
      t.string :slug                           # "2026-W21"
      t.jsonb  :target_axes, default: {}       # {age, gender, occupation, lifestyle}
      t.jsonb  :tone_axes,   default: {}       # {gentle, cute, funny, ...}
      t.jsonb  :seasons,     default: []
      t.jsonb  :emotions,    default: []
      t.jsonb  :usage_scenes, default: []
      t.jsonb  :keywords,    default: []
      t.text   :findings                       # body の構造化版(マークダウンOK)
      t.text   :brand_ideas                    # この調査から派生しうるブランド方向性
      t.text   :line_market_insights           # LINEで売れているパターン
      t.text   :communication_substitute_needs # 検索性・コミュニケーション代替の知見
    end
    add_index :linestamp_researches, :slug, unique: true
  end
end
```

### ★★★ Sprint B: PromptComposer 全面書き直し

#### B-1. Brand base_image プロンプトの仕様

```ruby
def compose_brand_prompt(brand)
  parts = brand.character_parts || {}
  fonts = brand.font_spec || {}

  <<~PROMPT.strip
    あなたはLINEスタンプキャラクターのキャラ仕様シートを描くデザイナーです。

    ## キャラクター定義
    #{brand.two_part_definition}

    ## キャラパーツ仕様(必須遵守)
    - 目: #{parts['eyes']}
    - 口: #{parts['mouth']}
    - 耳: #{parts['ears']}
    - 体型: #{parts['body']}
    - 手足: #{parts['limbs']}
    - しっぽ: #{parts['tail']}
    - 首輪: #{parts['collar']}

    ## フォント仕様
    - 基本: #{fonts['primary']}
    - 色: #{fonts['color']}
    - フチ: #{fonts['outline']}

    ## トーン
    #{brand.tone_axes.map { |k,v| "#{k}: #{(v*100).round}%" }.join(', ')}

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
```

#### B-2. Pack sheet プロンプト + 参照画像

```ruby
def compose_pack_sheet_prompt(pack)
  brand = pack.brand
  spec  = pack.image_spec
  stamps = pack.stamps.order(:position).map { |s|
    "##{s.position} 「#{s.label}」 - #{s.situation} (意図: #{s.intent}, 小道具: #{s.props})"
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
    #{pack.usage_scenes.join(', ')}

    ## ターゲット感情
    #{pack.target_emotions.join(', ')}

    ## 採用しない要素(派生パックへの含み)
    #{pack.excluded_elements}

    ## 出力形式
    8枚スタンプの一覧シート(2行 × 4列):
    #{stamps}

    ## キャラ仕様(brand.base_image と完全一致)
    線・色・体型・目・首輪を一切変えないこと。
    顔のサイズ・線の太さ・パステル色味も基準シート通り。

    ## 文字スタイル(brand.base_image のフォント基準と完全一致)
    太丸・濃ブラウン・太い白フチ(基準シート下部の「おつかれ/りょうかい/OK」と同じ)

    ## 背景
    単色グリーン #{brand.background_color_for_gen}

    ## サイズ
    各コマは正方形、最終的に LINE 規格 #{spec.width}×#{spec.height} で書き出される前提
  PROMPT
end
```

#### B-3. Stamp 個別プロンプト + 二重参照画像

```ruby
def compose_stamp_prompt(stamp)
  pack  = stamp.pack
  brand = pack.brand
  spec  = pack.image_spec

  <<~PROMPT.strip
    あなたは個別LINEスタンプのデザイナーです。

    ## 必ず参照する画像(両方添付すること)
    1. brand.base_image — キャラ仕様シート(揺れ防止のため)
    2. pack.sheet_image — 該当パックの8枚一覧シート(パック内一貫性のため)

    Designer ではこの2枚を参照画像として添付してください。

    ## スタンプ #{stamp.position}
    - ラベル: 「#{stamp.label}」
    - 想定シーン: #{stamp.usage_scene}
    - シチュエーション: #{stamp.situation}
    - 送信意図: #{stamp.intent}
    - コミュニケーション代替価値: #{stamp.communication_purpose}
    - ポーズ: #{stamp.pose_spec}
    - 小道具: #{stamp.props}
    - 検索キーワード: #{stamp.search_keywords.join(', ')}

    ## キャラ仕様(brand.base_image と完全一致)
    線・色・体型・目・首輪を一切変えないこと。
    新しい解釈を加えない。

    ## 文字仕様
    - 文言: 「#{stamp.label}」を中央上部に配置
    - スタイル: brand.base_image のフォント基準と完全一致
    - 漢字は正しく丁寧に。崩れたら再生成。ひらがなに逃げない

    ## 画像規格
    - サイズ: #{spec.width}×#{spec.height}
    - 背景: 単色グリーン(#{brand.background_color_for_gen})
    - 1画像1スタンプ
    - キャラがスタンプ領域の80%以上
  PROMPT
end
```

### ★★★ Sprint C: 管理画面の参照画像同梱

#### C-1. Brand 詳細ページに追加

- 「📥 Designer 同梱パッケージ DL」ボタン → brand_prompt.txt + base_image.png を zip
- フォント仕様表示
- キャラパーツ別プロンプト表示(eyes/mouth/.../collar 各々)
- トーン軸のレーダーチャート表示(なくてもいいがあると判断しやすい)
- 二段定義を冒頭に大きく表示

#### C-2. Pack 詳細ページに追加

- **brand.base_image をサイドで表示** (Designer 時にすぐ見られる)
- 「📥 Designer 同梱パッケージ DL」ボタン → sheet_prompt.txt + brand.base_image + 世界観メモ を zip
- 採用しない要素のセクション
- usage_scenes / target_emotions の構造化表示

#### C-3. Stamp 詳細ページに追加(最重要)

- **brand.base_image と pack.sheet_image を両方サイドに表示**
- 「📥 Designer 同梱パッケージ DL」ボタン →
  - stamp_prompt.txt
  - brand.base_image (参照1)
  - pack.sheet_image (参照2)
  - をまとめて zip
- intent / situation / search_keywords / props を構造化表示

#### C-4. 新規 LineExporter 拡張

既存の LineExporter は 8 stamp の processed_image を zip にするだけ。
新規に **DesignerKit::Brand / DesignerKit::Pack / DesignerKit::Stamp** を作成:

```ruby
module Linestamp
  module DesignerKit
    class Stamp
      def initialize(stamp)
        @stamp = stamp
      end

      def zip
        Zip::OutputStream.write_buffer do |zos|
          zos.put_next_entry("prompt.txt")
          zos.write(@stamp.prompt)

          zos.put_next_entry("README.md")
          zos.write(readme_text)

          if @stamp.pack.brand.base_image.attached?
            zos.put_next_entry("references/brand_base.png")
            @stamp.pack.brand.base_image.download { |c| zos.write(c) }
          end
          if @stamp.pack.sheet_image.attached?
            zos.put_next_entry("references/pack_sheet.png")
            @stamp.pack.sheet_image.download { |c| zos.write(c) }
          end
        end.string
      end

      private
      def readme_text
        <<~TXT
          # Stamp ##{@stamp.position} 「#{@stamp.label}」

          Designer に貼り付ける手順:
          1. prompt.txt の内容をコピーして Designer に貼る
          2. references/brand_base.png と pack_sheet.png を参照画像として添付
          3. 生成
          4. ダウンロードしたら管理画面の Upload Raw で再アップロード

          シチュエーション: #{@stamp.situation}
          意図: #{@stamp.intent}
        TXT
      end
    end
  end
end
```

### ★★ Sprint D: brand_sources/ の seed 修復

#### D-1. nemuinu の 01_brand_theme.md を引継ぎ仕様に戻す

**現状(壊れてる)**:
```markdown
# ブランドテーマ: ねむ犬
## コンセプト
いつも眠そうな犬「ねむ犬」の日常を描くLINEスタンプシリーズ。
ゆるくて脱力系、でも愛おしい。
```

**修復後**:
```markdown
# 01_brand_theme.md — ねむ犬

## ブランドテーマ
### シリーズ名
在宅ワークのゆる犬
### キャラクター名
ねむ犬

---
## ブランドの最重要定義
**ねむ犬は「かわいい犬」ではない。**
**ねむ犬は、眠そうだけどちゃんと仕事している、在宅ワーク中の犬である。**

---
## 優先順位
### 1. ねむそう(最優先)
- 細い半目(必須)
- 目は開かない
- まぶたが少し重い
### 2. 在宅ワークの空気
- 少し気まずい
- 少し力が抜けている
### 3. ふんわり・ほわほわ
- 線が丸い、角がない

## NG/OK ...
## 表現レイヤー Core/Work/Dream ...
```

(引継ぎ済の nemuinu_handover_bundle 内の本物を seed として配置)

#### D-2. manifest.yml を引継ぎ仕様に

```yaml
slug: "pack_001"
series_theme: "在宅ワーク基本"
layer: "core_work"
world_view: "朝から夕方までの在宅勤務中のさまざまなシーン"
usage_scenes: ["朝の起動", "PC作業中", "会議中", "休憩", "終業後"]
target_emotions: ["気まずさ", "ねぎらい", "ぼんやり", "やる気フリ"]
excluded_elements: "雲・星・寝帽子(Dream Layer 派生で使用予定)"
stamps:
  - number: 1
    label: "いま仕事中だよ"
    situation: "PC前で作業。半目・無表情"
    intent: "ステータス通知(返信遅延の申し訳なさ)"
    usage_scene: "返信できない時"
    pose_spec: "ノートPC覗き込み、座り"
    props: "ノートPC"
    search_keywords: ["仕事中", "PC", "返事", "あとで"]
    communication_purpose: "話せないが無視じゃないと伝える"
  # ... 8件
```

#### D-3. BrandSourcesSyncer の拡張

manifest.yml の追加カラムを Stamp に sync するロジック追加。
01_brand_theme.md / 02_base.md からも構造化情報(キャラパーツ等)を抽出するロジック追加。

### ★★ Sprint E: その他

- 緑色を `#00FF00` から `#3CB371` (sea green、ねむ犬実績色)に統一
- ChromaKeyProcessor は image_spec から width/height を取るように変更
- StampsController の `upload_processed` は AASM の force_processed イベントを呼ぶように修正
- Slack 通知に Stamp 完成画像を必ず添付(現状 webhook 単発のみ)

### ★★★ Sprint F: LINE main_image (240×240) / tab_image (96×74) の実生成

LINE 申請に必須なので **テーブル準備だけでなく実生成まで** 通す。

#### F-1. Pack に画像添付追加

```ruby
# app/models/linestamp/pack.rb
has_one_attached :sheet_image         # 既存(8枚一覧)
has_one_attached :main_image          # ★追加(240×240 パック代表画像)
has_one_attached :tab_image           # ★追加(96×74 タブ画像)
```

#### F-2. Pack に「どのstampを元に作るか」列を追加

```ruby
class AddRepresentativeStampsToLinestampPacks < ActiveRecord::Migration[8.1]
  def change
    change_table :linestamp_packs do |t|
      t.references :main_source_stamp, foreign_key: { to_table: :linestamp_stamps }, null: true
      t.references :tab_source_stamp,  foreign_key: { to_table: :linestamp_stamps }, null: true
    end
  end
end
```

#### F-3. ChromaKeyProcessor を image_spec 対応に

```ruby
# app/services/linestamp/chroma_key_processor.rb
def call(input_path, spec: nil)
  spec ||= ::Linestamp::ImageSpec.find_by!(slug: "line_main_370x320")
  w, h, margin = spec.width, spec.height, spec.margin_px
  content_w = w - margin * 2
  content_h = h - margin * 2

  output = Tempfile.new(["chroma_out", ".png"], binmode: true)
  output.close

  MiniMagick::Tool::Convert.new do |c|
    c << input_path
    c.fuzz "25%"
    c.transparent "green"
    c.channel "G"
    c.evaluate "Multiply", "0.85"
    c.channel "RGBA"
    c.trim
    c.merge! ["+repage"]
    c.background "none"
    c.resize "#{content_w}x#{content_h}>"
    c.gravity "center"
    c.extent "#{w}x#{h}"
    c << output.path
  end
  Tempfile.open(["chroma_result", ".png"], binmode: true) do |f|
    f.write(File.binread(output.path))
    f.rewind
    return f
  end
ensure
  output&.unlink
end
```

#### F-4. PackRepresentativeImageGenerator サービス新規

```ruby
# app/services/linestamp/pack_representative_image_generator.rb
module Linestamp
  class PackRepresentativeImageGenerator
    KIND_TO_SPEC = {
      main: "line_main_240x240",
      tab:  "line_tab_96x74"
    }.freeze

    # @param pack [Linestamp::Pack]
    # @param kind [:main, :tab]
    # @param source_stamp [Linestamp::Stamp] 元画像にする stamp(processed_image 必須)
    def call(pack:, kind:, source_stamp:)
      spec = ::Linestamp::ImageSpec.find_by!(slug: KIND_TO_SPEC.fetch(kind))
      raise "source_stamp.processed_image not attached" unless source_stamp.processed_image.attached?

      # processed_image はもう透過済みなので、緑透過は不要だが規格リサイズだけする
      raw = save_attachment_to_tempfile(source_stamp.processed_image)
      out = resize_only(raw.path, spec)

      target = (kind == :main) ? pack.main_image : pack.tab_image
      target.attach(io: out, filename: "#{kind}.png", content_type: "image/png")

      # 元stamp を記録
      pack.update_column((kind == :main ? :main_source_stamp_id : :tab_source_stamp_id), source_stamp.id)
    ensure
      raw&.close
      raw&.unlink
    end

    private

    def resize_only(input_path, spec)
      output = Tempfile.new(["resize_out", ".png"], binmode: true)
      output.close
      MiniMagick::Tool::Convert.new do |c|
        c << input_path
        c.background "none"
        c.resize "#{spec.width - spec.margin_px*2}x#{spec.height - spec.margin_px*2}>"
        c.gravity "center"
        c.extent "#{spec.width}x#{spec.height}"
        c << output.path
      end
      f = Tempfile.new(["resize_result", ".png"], binmode: true)
      f.write(File.binread(output.path))
      f.rewind
      f
    end

    def save_attachment_to_tempfile(attachment)
      f = Tempfile.new(["attached", ".png"], binmode: true)
      attachment.download { |chunk| f.write(chunk) }
      f.rewind
      f
    end
  end
end
```

#### F-5. 管理画面 UI

Pack 詳細に以下を追加:

```erb
<!-- main_image -->
<div class="card">
  <h2>Main Image (240×240, LINE申請用)</h2>
  <% if @pack.main_image.attached? %>
    <%= image_tag url_for(@pack.main_image), style: "max-width:240px; border:1px solid #ccc;" %>
  <% else %>
    <p>未設定</p>
  <% end %>
  
  <!-- 手動アップロード -->
  <%= form_with url: upload_main_image_admin_linestamp_pack_path(@pack), multipart: true do |f| %>
    <%= f.label :main_image, "Designer で作った 240×240 を直接アップロード" %>
    <%= f.file_field :main_image %>
    <%= f.submit "Upload Main", class: "btn btn-primary btn-sm" %>
  <% end %>
  
  <!-- stamp から生成 -->
  <%= form_with url: generate_main_image_admin_linestamp_pack_path(@pack), method: :post do |f| %>
    <%= f.select :source_stamp_id, @pack.stamps.where(status: "processed").map { |s| ["##{s.position} #{s.label}", s.id] } %>
    <%= f.submit "選んだ Stamp から自動生成", class: "btn btn-secondary btn-sm" %>
  <% end %>
</div>

<!-- tab_image も同様 -->
```

#### F-6. ルート追加

```ruby
resources :packs do
  member do
    post :upload_main_image
    post :generate_main_image
    post :upload_tab_image
    post :generate_tab_image
  end
end
```

#### F-7. LineExporter 拡張

```ruby
def zip
  Zip::OutputStream.write_buffer do |zos|
    # 既存: 8枚の stamp.processed_image を 01.png 〜 08.png
    @pack.stamps.order(:position).each do |stamp|
      next unless stamp.processed_image.attached?
      zos.put_next_entry(format("%02d.png", stamp.position))
      stamp.processed_image.download { |c| zos.write(c) }
    end

    # ★追加: main.png
    if @pack.main_image.attached?
      zos.put_next_entry("main.png")
      @pack.main_image.download { |c| zos.write(c) }
    end

    # ★追加: tab.png
    if @pack.tab_image.attached?
      zos.put_next_entry("tab.png")
      @pack.tab_image.download { |c| zos.write(c) }
    end
  end.string
end
```

#### F-8. Pack の完了判定強化

`Pack#may_complete_all?` の guard を更新:

```ruby
event :complete_all, after: :ensure_draft_submission do
  transitions from: :stamps_generating, to: :complete,
              guard: ->(pack) {
                pack.stamps.any? &&
                pack.stamps.all?(&:processed?) &&
                pack.main_image.attached? &&     # ★追加
                pack.tab_image.attached?         # ★追加
              }
end
```

これで「全 stamp processed + main + tab すべて揃って初めて complete」になる。

---

### ★★★ Sprint G: 旧カラム完全削除(後方互換打ち切り)

Phase 1 で `name / title / emotion / text_overlay` を残したまま新カラムを追加したが、
本 Phase で完全移行 → 旧カラム drop まで一気にやる。

#### G-1. 旧→新の対応関係

| 旧カラム | 新カラム | データ移行ロジック |
|---|---|---|
| `linestamp_brands.name` | `linestamp_brands.character_name` | UPDATE...WHERE character_name IS NULL: character_name = name |
| `linestamp_packs.title` | `linestamp_packs.series_theme` | UPDATE...WHERE series_theme IS NULL: series_theme = title |
| `linestamp_stamps.emotion` | `linestamp_stamps.intent` | UPDATE...WHERE intent IS NULL: intent = emotion |
| `linestamp_stamps.text_overlay` | `linestamp_stamps.label` | UPDATE...WHERE label IS NULL: label = text_overlay |

#### G-2. データ移行マイグレーション

```ruby
class BackfillLegacyColumnsToStructuredFields < ActiveRecord::Migration[8.1]
  def up
    # Idempotent: 新カラムが空のレコードだけ埋める
    Linestamp::Brand.where(character_name: [nil, ""]).find_each do |b|
      b.update_columns(character_name: b[:name].presence || b.slug)
    end
    Linestamp::Brand.where(series_name: [nil, ""]).find_each do |b|
      b.update_columns(series_name: b[:name].presence || b.slug)
    end
    Linestamp::Pack.where(series_theme: [nil, ""]).find_each do |p|
      p.update_columns(series_theme: p[:title].presence || "pack_#{p.position}")
    end
    Linestamp::Pack.where(slug: [nil, ""]).find_each do |p|
      p.update_columns(slug: "pack_#{p.position.to_s.rjust(3, '0')}")
    end
    Linestamp::Stamp.where(label: [nil, ""]).find_each do |s|
      s.update_columns(label: s[:text_overlay].presence || "##{s.position}")
    end
    Linestamp::Stamp.where(intent: [nil, ""]).find_each do |s|
      s.update_columns(intent: s[:emotion]) if s[:emotion].present?
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
```

#### G-3. 全コード参照を新カラムに置換

| 旧 | 新 |
|---|---|
| `brand.name` | `brand.character_name`(キャラ名表示時)/ `brand.series_name`(シリーズ大名称) |
| `pack.title` | `pack.series_theme` |
| `stamp.emotion` | `stamp.intent` |
| `stamp.text_overlay` | `stamp.label` |

書き換え対象:
- 全 view (`app/views/admin/linestamp/**.html.erb`)
- 全 controller / service / job
- spec files
- PromptComposer 内の参照
- BrandSourcesSyncer

#### G-4. 旧カラム drop マイグレーション

```ruby
class DropLegacyColumnsFromLinestampTables < ActiveRecord::Migration[8.1]
  def up
    remove_column :linestamp_brands, :name        if column_exists?(:linestamp_brands, :name)
    remove_column :linestamp_packs, :title        if column_exists?(:linestamp_packs, :title)
    remove_column :linestamp_stamps, :emotion     if column_exists?(:linestamp_stamps, :emotion)
    remove_column :linestamp_stamps, :text_overlay if column_exists?(:linestamp_stamps, :text_overlay)
  end

  def down
    # 復旧不可(Phase 2 完了後は旧カラム使わない方針)
    raise ActiveRecord::IrreversibleMigration
  end
end
```

#### G-5. validation の置き換え

旧:
```ruby
validates :name, presence: true
```

新:
```ruby
validates :character_name, presence: true
validates :series_name,    presence: true
```

(以下同様、全モデル)

#### G-6. brand_sources_syncer のフィールド名修正

旧マニフェスト読み取り処理が `stamp_data["text"]` / `stamp_data["emotion"]` を見てる箇所を
新マニフェスト `label` / `intent` / `situation` / `usage_scene` / `pose_spec` / `props` / `search_keywords` / `communication_purpose` 読み取りに変更。

---

### ★★★ Sprint H: 企画 workflow の中身を実装(現状 TODO スタブ)

Phase 1 で `linestamp-research.yml` / `linestamp-brand-planning.yml` / `linestamp-pack-planning.yml` の3本が **echo "TODO..." の空殻** として作られている。

```yaml
# 現状(全3ワークフロー共通)
- name: Run research task
  run: |
    echo "Linestamp research workflow triggered"
    echo "TODO: Implement research automation"
```

→ workflow_dispatch で手動実行しても **何も起きない**。Copilot Coding Agent への Issue 起票がされない。

#### H-1. 修正方針

myapp の既存運用パターン(CLAUDE.md「Copilot coding agent を Issue から起動するには…」参照)に揃える:

1. **`DEPLOY_TOKEN`(個人 PAT)で Issue 作成** ← `GITHUB_TOKEN` だと Copilot が反応しない
2. **assignees に `copilot-swe-agent[bot]` を追加**(正しい bot ユーザー名)
3. **`@copilot` メンションコメントを別途投稿**(本文に書いても起動しない)
4. ブランチ命名は `copilot/linestamp-research-*` 等(`copilot/ai-sns-*` パターンに準拠)

#### H-2. `linestamp-research.yml` の完成版

```yaml
name: Linestamp Research
on:
  workflow_dispatch:
    inputs:
      focus:
        description: "今週の調査フォーカス(空でも可)"
        required: false
        default: ""
  schedule:
    - cron: '0 0 * * 1'  # 月曜 0:00 UTC = 月曜 9:00 JST

jobs:
  create-research-issue:
    runs-on: [self-hosted, sakura-vps]
    permissions:
      contents: read
      issues: write
    steps:
      - uses: actions/checkout@v4

      - name: Compute ISO week
        id: week
        run: |
          WEEK=$(date -u +"%Y-W%V")
          echo "iso_week=$WEEK" >> $GITHUB_OUTPUT

      - name: Create research issue and assign Copilot
        env:
          GH_TOKEN: ${{ secrets.DEPLOY_TOKEN }}
        run: |
          WEEK="${{ steps.week.outputs.iso_week }}"
          FOCUS="${{ inputs.focus }}"
          [ -z "$FOCUS" ] && FOCUS="今週注目のLINEスタンプトレンド・季節要素・感情ニーズ"

          BODY=$(cat <<EOF
          ## ミッション
          LINEスタンプ企画のための週次調査を実施し、結果を \`brand_sources/research/${WEEK}/\` に出力してください。

          ## 出力ファイル
          - \`brand_sources/research/${WEEK}/findings.md\` (本文)
          - \`brand_sources/research/${WEEK}/trends.yml\` (構造化キーワード)
          - \`brand_sources/research/${WEEK}/brief.md\` (この issue 本文をコピー)

          ## 調査フォーカス
          ${FOCUS}

          ## 仕様
          \`docs/linestamp/08_PLANNING_GUIDE.md\` の「## 調査 (Research)」セクション参照。

          ## 完了条件
          - [ ] findings.md に最低5つの利用シーン
          - [ ] findings.md に最低3つの感情ニーズ
          - [ ] trends.yml に keywords / seasons / emotions / age_groups 各配列
          - [ ] PR が作成され draft でレビュー待ち
          EOF
          )

          # 1. Issue 作成
          ISSUE_URL=$(gh issue create \
            --title "[linestamp/research] ${WEEK} 週次調査" \
            --label "linestamp,research,auto" \
            --body "$BODY")
          ISSUE_NUMBER=$(echo "$ISSUE_URL" | grep -oE '[0-9]+$')
          echo "Created: $ISSUE_URL"

          # 2. Copilot bot をアサイン(コメントは assignee 追加の前に投稿)
          gh issue comment $ISSUE_NUMBER --body "@copilot 上記の調査をお願いします。docs/linestamp/08_PLANNING_GUIDE.md を必読。"
          gh issue edit $ISSUE_NUMBER --add-assignee "copilot-swe-agent[bot]"
```

#### H-3. `linestamp-brand-planning.yml` の完成版

(同様の構造で、`count` 入力 + ループで複数 Issue 作成)

```yaml
name: Linestamp Brand Planning
on:
  workflow_dispatch:
    inputs:
      count:
        description: "ブランド企画数(default=3)"
        required: false
        default: "3"
  schedule:
    - cron: '0 22 * * *'  # 22:00 UTC = 翌7:00 JST

jobs:
  create-brand-issues:
    runs-on: [self-hosted, sakura-vps]
    permissions:
      contents: read
      issues: write
    steps:
      - uses: actions/checkout@v4

      - name: Find latest research
        id: research
        run: |
          LATEST=$(ls -1 brand_sources/research/ 2>/dev/null | sort | tail -1 || echo "none")
          echo "slug=$LATEST" >> $GITHUB_OUTPUT

      - name: Create brand planning issues
        env:
          GH_TOKEN: ${{ secrets.DEPLOY_TOKEN }}
        run: |
          COUNT="${{ inputs.count }}"
          [ -z "$COUNT" ] && COUNT="3"
          RESEARCH="${{ steps.research.outputs.slug }}"
          DATE=$(date -u +"%Y-%m-%d")

          for i in $(seq 1 $COUNT); do
            BODY=$(cat <<EOF
          ## ミッション
          新規LINEスタンプブランドの企画書一式を \`brand_sources/{新slug}/\` に作成してください。

          ## 参考にする調査
          \`brand_sources/research/${RESEARCH}/findings.md\` を必ず読むこと。

          ## 出力
          - \`brand_sources/{slug}/01_brand_theme.md\`
          - \`brand_sources/{slug}/02_base.md\`
          - \`brand_sources/{slug}/meta.yml\`

          ## 仕様
          \`docs/linestamp/08_PLANNING_GUIDE.md\` の「## Brand 企画」を参照。
          既存ブランド \`brand_sources/nemuinu/\` をお手本にする。

          ## 完了条件
          - [ ] 二段定義: 「○○ではない、○○な△△」
          - [ ] 優先順位3つを明示
          - [ ] Core/Work/Dream の表現レイヤー定義
          - [ ] meta.yml に character_parts / font_spec / tone_axes が入っている
          - [ ] PR がレビュー待ち
          EOF
          )

            ISSUE_URL=$(gh issue create \
              --title "[linestamp/brand] ${DATE} #${i}" \
              --label "linestamp,brand-planning,auto" \
              --body "$BODY")
            ISSUE_NUMBER=$(echo "$ISSUE_URL" | grep -oE '[0-9]+$')
            echo "Created: $ISSUE_URL"

            gh issue comment $ISSUE_NUMBER --body "@copilot 新ブランド企画をお願いします。"
            gh issue edit $ISSUE_NUMBER --add-assignee "copilot-swe-agent[bot]"

            sleep 3
          done
```

#### H-4. `linestamp-pack-planning.yml` の完成版

```yaml
name: Linestamp Pack Planning
on:
  workflow_dispatch:
    inputs:
      count:
        description: "Pack企画数(default=10)"
        required: false
        default: "10"
  schedule:
    - cron: '30 22 * * *'  # 22:30 UTC = 翌7:30 JST

jobs:
  create-pack-issues:
    runs-on: [self-hosted, sakura-vps]
    permissions:
      contents: read
      issues: write
    steps:
      - uses: actions/checkout@v4

      - name: List active brands
        id: brands
        run: |
          BRANDS=$(ls -1d brand_sources/*/ 2>/dev/null | xargs -n1 basename | grep -v '^_' | grep -v '^research$' | tr '\n' ',' | sed 's/,$//')
          [ -z "$BRANDS" ] && BRANDS="nemuinu"
          echo "list=$BRANDS" >> $GITHUB_OUTPUT

      - name: Create pack planning issues
        env:
          GH_TOKEN: ${{ secrets.DEPLOY_TOKEN }}
        run: |
          COUNT="${{ inputs.count }}"
          [ -z "$COUNT" ] && COUNT="10"
          IFS=',' read -ra BRANDS <<< "${{ steps.brands.outputs.list }}"
          DATE=$(date -u +"%Y-%m-%d")
          NUM_BRANDS=${#BRANDS[@]}

          for i in $(seq 1 $COUNT); do
            BRAND=${BRANDS[$(((i-1) % NUM_BRANDS))]}

            BODY=$(cat <<EOF
          ## ミッション
          既存ブランド \`${BRAND}\` に新しいシリーズ(Pack)を企画してください。
          出力先: \`brand_sources/${BRAND}/packs/{新pack_slug}/\`

          ## ベースブランド
          \`brand_sources/${BRAND}/01_brand_theme.md\` と \`02_base.md\` を必読。
          ブランドのキャラ・世界観・トーンを尊重すること。

          ## 出力ファイル
          - \`brand_sources/${BRAND}/packs/{slug}/03_stamp_pack.md\`
          - \`brand_sources/${BRAND}/packs/{slug}/manifest.yml\` (新仕様: situation/intent/usage_scene/pose_spec/props/search_keywords/communication_purpose)

          ## 仕様
          \`docs/linestamp/08_PLANNING_GUIDE.md\` の「## Pack 企画」を参照。
          既存ねむ犬 \`brand_sources/nemuinu/packs/pack_001/manifest.yml\` を雛形に。

          ## 完了条件
          - [ ] 8枚すべてに label/situation/intent/usage_scene/pose_spec/props/search_keywords/communication_purpose
          - [ ] パック内で利用シーンに統一感
          - [ ] 既存 pack と重複しないテーマ
          - [ ] PR がレビュー待ち
          EOF
          )

            ISSUE_URL=$(gh issue create \
              --title "[linestamp/pack] ${DATE} ${BRAND} #${i}" \
              --label "linestamp,pack-planning,auto" \
              --body "$BODY")
            ISSUE_NUMBER=$(echo "$ISSUE_URL" | grep -oE '[0-9]+$')
            echo "Created: $ISSUE_URL"

            gh issue comment $ISSUE_NUMBER --body "@copilot 新シリーズ企画をお願いします。"
            gh issue edit $ISSUE_NUMBER --add-assignee "copilot-swe-agent[bot]"

            sleep 2
          done
```

#### H-5. `linestamp-sync.yml`(brand_sources/ 更新時に Rails sync を叩く)

Phase 1 で確認漏れ。`linestamp-sync.yml` も同じく TODO スタブの可能性。確認 + 実装する。

```yaml
name: Linestamp Sync to Rails
on:
  push:
    branches: [main]
    paths:
      - 'brand_sources/**'

jobs:
  sync:
    runs-on: [self-hosted, sakura-vps]
    steps:
      - uses: actions/checkout@v4
      - name: Trigger Rails sync via local HTTP
        env:
          SYNC_TOKEN: ${{ secrets.LINESTAMP_SYNC_TOKEN }}
        run: |
          curl -sf -X POST http://localhost:3000/webhooks/linestamp/sync \
            -H "Authorization: Bearer $SYNC_TOKEN" \
            -H "Content-Type: application/json" || echo "Rails sync failed (Rails not running?)"
      - name: Notify Slack
        if: success()
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
        run: |
          if [ -n "$SLACK_WEBHOOK_URL" ]; then
            curl -sf -X POST $SLACK_WEBHOOK_URL \
              -H "Content-Type: application/json" \
              -d "{\"text\":\"🔄 brand_sources synced to Rails (${{ github.sha }})\"}"
          fi
```

#### H-6. 前提となる Secrets

myapp リポの GitHub Secrets に以下が登録されていること(`DEPLOY_TOKEN` は既存運用で使用中のはず):

| Secret | 用途 | 既存 |
|---|---|---|
| `DEPLOY_TOKEN` | Issue 作成・Copilot アサイン用 PAT(fine-grained、Issues/Pull requests/Contents の RW) | ✅ あるはず |
| `LINESTAMP_SYNC_TOKEN` | webhook 認証 | ❌ 新設(rails secret で生成) |
| `SLACK_WEBHOOK_URL` | sync 完了通知 | ✅ あるはず(WEBHOOK_URL_JOBS 等) |

---

## Sprint A〜H 全体まとめ

```
Sprint A: スキーマ拡張(10マイグレ)
Sprint B: PromptComposer 全面書き直し
Sprint C: 管理画面の参照画像同梱(DesignerKit)
Sprint D: brand_sources/nemuinu/ seed 修復
Sprint E: 緑色 #3CB371 統一+その他
Sprint F: main_image(240×240) / tab_image(96×74) 実生成
Sprint G: 旧カラム完全削除
Sprint H: 企画 workflow の中身を実装(現状 TODO スタブ)★追加
```

合計マイグレーション: 10本
合計新規ファイル: 約 65
変更ファイル: 約 35(workflow 4本含む)
推定行数: 3500〜5500行

---

## 修正用 Issue 本文(Copilot 投入用)

`docs/linestamp/17_PHASE2_ISSUE.md` に Copilot 投入用 Issue 本文を別途用意。

---

## 修正版で実現される姿

```
管理画面 Stamp #1 詳細
├── ラベル: 「いま仕事中だよ」
├── シチュエーション: PC前で作業。半目・無表情
├── 意図: ステータス通知(返信遅延の申し訳なさ)
├── 検索キーワード: 仕事中, PC, 返事, あとで
├── プロンプト: (構造化された Designer 指示文)
├── 📋 プロンプトコピー
├── サイド:
│   ├── brand.base_image (12構図 + 3フォント基準)
│   └── pack.sheet_image (8枚一覧)
└── 📥 Designer Kit DL (上記3つを zip)

→ 原田さんは zip 1個だけ DL して Designer にバッと貼るだけ
```

これが当初の "ユーザーが迷わない" 設計。

---

## まとめ

Phase 1 実装は「型は作れたが魂が抜けた」状態。
Phase 2 修正でやることは:

1. **DB を構造化**(text/jsonb 詰め込み → 専用カラム)
2. **LINE規格マスタテーブル**追加
3. **PromptComposer 全面書き直し**(参照画像同梱 + 12構図 + 3フォント等)
4. **管理画面に参照画像同梱**(Stamp詳細から zip 1発で全部取れる)
5. **brand_sources/nemuinu** を引継ぎ仕様に戻す
6. **manifest.yml** にシーン/意図/検索キーワード等を復活
7. **緑色を `#3CB371`** に統一

これらが揃って初めて「品質を維持できる LINE スタンプ工房」になる。
