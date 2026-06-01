# Linestamp Planning Guide — Ruby Seed DSL ベース

> **正本**: このドキュメントが Linestamp 企画フローの唯一の仕様書。
> **旧 md/yml フォーマットは廃止済み** — `brand_sources/` ディレクトリは削除された。

## 全体像

```
DB = Single Source of Truth (SoT)
    ↑ ↑ ↑
    │ │ └── 管理画面で直接編集 (Admin UI)
    │ └──── Ruby seed ファイル (Copilot が書く)
    └────── linestamp:apply_imports (merge 時に自動実行)
```

1. **Copilot** が Ruby seed ファイルを `db/seeds/linestamp/imports/pending/` に配置
2. PR を main に merge すると GitHub Actions が `bin/rails linestamp:apply_imports` を自動実行
3. seed が DB に反映され、ファイルは `applied/` に自動移動
4. 管理画面 (Admin UI) からの直接編集も可能で、上書きされない

### Research → Brand 系譜（重要）

調査(Research)は捨て資産にしない。**Brand は必ず起点となった Research を `research_slug` で指す**。

```
Research(調査・brand_ideas) ──research_slug──▶ Brand(キャラ+世界観) ──▶ Pack ──▶ Stamp
```

- `linestamp-research.yml` が Research を生み、その `brand_ideas` が次のブランド企画の素材になる
- `linestamp-brand-planning.yml` は **最新の applied Research の `brand_ideas` を Issue 本文に埋め込み**、企画者にそこからの選択・合成を強制する
- Brand seed には採用した Research の `research_slug` を必ず書く（データで系譜を追跡する）
- 「またかわいい動物」量産を防ぐ仕組み = **Research の brand_idea 起点 + identity_axes** の 2 段で差別化を出す

## ファイル名規約

```
{YYYY-MM-DD-HHMMSS}_{kind}_{slug}.rb
```

- 時刻は **UTC**
- `kind`: `brand` / `pack` / `research`
- `slug`: 英数字+アンダースコア（ブランド名 or パック名 or リサーチテーマ）

例: `2026-05-26-120000_brand_nemuinu.rb`

## 共通ルール

1. **テンプレ必須参照**: `db/seeds/linestamp/imports/_templates/` 内の対応テンプレートを必ず雛形にする
2. **マスタ slug 検証**: 使用前に `bin/rails runner 'puts Linestamp::CommunicationTheme.pluck(:slug,:name)'` で確認。未知 slug はエラーで全 transaction rollback
3. **1 PR = 1 ファイル**: ファイル単位で冪等実行される
4. **seed_id の一意性**: ファイル名（拡張子除く）が seed_id。重複実行は skip される
5. **構文チェック**: `ruby -c` でエラーがないことを PR 前に確認

## マスタデータ一覧

### AttributeAxis (4軸)

| slug | name | kind |
|------|------|------|
| tone | トーン | tone |
| motif | モチーフ | motif |
| demographic | デモグラフィ | demographic |
| setting | シーン | setting |

### AttributeValue (34値)

#### tone (8)
gentle(ゆるい) / neat(きっちり) / surreal(シュール) / cute(かわいい) / cool(かっこいい) / stylish(おしゃれ) / funny(おもしろい) / elegant(上品)

#### motif (8)
animal(動物) / food(食べ物) / plant(植物) / human(人物) / monster(モンスター) / abstract(抽象) / vehicle(乗り物) / tool(道具)

#### demographic (10)
age_10s(10代) / age_20s(20代) / age_30s(30代) / age_40s(40代) / age_50plus(50代以上) / for_male(男性向け) / for_female(女性向け) / unisex(性別不問) / business_user(ビジネス層) / student(学生)

#### setting (8)
home(家庭) / remote_work(在宅) / office(オフィス) / with_friends(友達同士) / with_lover(恋人) / with_family(家族) / boss_subordinate(上司部下) / with_customer(お客様)

### CommunicationTheme (18)

remote_work_report(在宅ワーク報告) / gratitude(感謝) / apology(謝罪) / agreement(相槌) / encouragement(励まし) / greeting_morning(おはよう) / greeting_night(おやすみ) / confirm_meetup(待ち合わせ確認) / on_the_way(今行く) / meal_invitation(食事の誘い) / friendly_tease(相手をいじる) / appreciation_for_effort(ねぎらい) / need_focus(集中したい) / need_break(休憩したい) / quick_answer(簡易回答) / urgent_contact(緊急連絡) / status_busy(忙しいアピール) / celebration(お祝い)

## Research 企画

リサーチは市場調査の結果を DB に保存するもの。**`brand_ideas` は後続のブランド企画が消費する**ので、具体的なブランド案を複数書く。

```ruby
Linestamp::Importer.run(seed_id: "2026-05-26-120000_research_remote_work_trends") do
  upsert_research!(
    slug: "remote_work_trends_2026w22",
    title: "在宅ワーク層のスタンプニーズ調査 2026-W22",
    body: "調査概要...",
    findings: "主な発見: ...",
    brand_ideas: "ブランドアイデア: ...",
    line_market_insights: "市場洞察: ...",
    communication_substitute_needs: "代替ニーズ: ...",
    source_url: "https://...",
    keywords: %w[在宅 リモート テレワーク],
    emotions: %w[安心 共感 ねぎらい],
    seasons: %w[all_year],
    communication_themes: %w[remote_work_report appreciation_for_effort],
    attributes: {
      demographic: %w[age_20s age_30s business_user],
      setting: %w[remote_work home]
    }
  )
end
```

## Brand 企画

ブランドは「キャラクター + 世界観」の単位。**起点 Research の `research_slug` を必ず指定**し、設計の核（二段定義・キャラパーツ・フォント・トーン軸・ターゲット軸・識別軸）をすべて埋める。

```ruby
Linestamp::Importer.run(seed_id: "2026-05-26-120000_brand_nemuinu") do
  brand = upsert_brand!(
    # この案の起点になった Research の slug（系譜トラッキング・必須）
    research_slug: "remote_work_trends_2026w22",

    slug: "nemuinu",
    character_name: "ねむ犬",
    series_name: "ねむ犬スタンプ",
    persona_name: "ねむ犬",
    concept: "いつも眠そうだけど仕事はきっちりこなす柴犬",
    target_audience: "20-30代 在宅ワーカー",
    description: "ゆるい表情で日常のコミュニケーションを柔らかくする",

    # 二段定義「○○ではない、○○な△△」で輪郭を絞る
    two_part_definition: "ただ眠いだけの犬ではない、仕事はきっちりこなす眠そうな柴犬",

    # キャラパーツ 7 部位（持たない部位は空文字で残す＝プロンプトに出ない）
    character_parts: {
      eyes:   "半目・下まぶたが重い",
      mouth:  "small",
      ears:   "垂れ耳",
      body:   "ずんぐり",
      limbs:  "短い",
      tail:   "丸まり気味",
      collar: ""        # 例: 首輪を持たないなら空のまま
    },

    # フォント仕様
    font_spec: {
      primary: "丸ゴシック",
      color:   "#5B4636",
      outline: "白フチ 2px"
    },

    # トーン軸（スコア付き jsonb・降順で展開される）
    tone_axes:   { gentle: 0.95, cute: 0.7, funny: 0.3 },
    # ターゲット軸
    target_axes: { age: %w[20s 30s], gender: "unisex", occupation: "在宅ワーカー" },

    # 識別軸（他ブランドと絶対に混同されない核・fill-or-empty）
    identity_axes: {
      signature: "右目の下に小さなほくろ",  # 必ず出す識別要素
      voice:     "断定しない・語尾がやわらかい",
      behavior:  "考えるとき宙を見る"
    },

    # 世界観カラー（透過用緑とは別物）
    primary_color: "#F5DEB3"
  )

  attach_communication_themes!(brand, %w[
    remote_work_report gratitude appreciation_for_effort
    greeting_morning greeting_night
  ])
  attach_attribute_values!(brand, {
    tone: %w[gentle cute],
    motif: %w[animal],
    demographic: %w[age_20s age_30s business_user],
    setting: %w[remote_work home office]
  })
end
```

### Brand で触ってはいけない / 書かないもの

- **`background_color_for_gen` は書かない**。モデルが透過用シーグリーン `#3CB371` に固定する（cowork の line-stamp-packaging スキルが緑透過するため緑背景固定）。世界観の色は `primary_color` に入れる。
- **プロンプト系カラム（`brand_prompt` / `sheet_prompt` / stamp の `prompt`）は書かない**。レコード作成時の `after_commit` で自動合成される。埋めると合成ガード（`prompt.blank?`）で何も起きなくなる。
- 差別化は**禁止語や特定部位のハードコードで出さない**。`research_slug` 起点 + `identity_axes` の構造化スロットで出す。使わない軸は空文字で残す（プロンプトには出ない）。

## Pack 企画

Pack は LINE 申請単位(8/24/40枚)のシリーズ。

```ruby
Linestamp::Importer.run(seed_id: "2026-05-26-120000_pack_nemuinu_remote_daily") do
  brand = Linestamp::Brand.find_by!(slug: "nemuinu")

  create_pack!(
    brand: brand,
    slug: "remote_daily",
    series_theme: "在宅ワークの日常",
    position: 1,
    layer: "core_work",
    purchase_unit_size: 8,
    world_view: "リモートワーク中の何気ない瞬間",
    communication_themes: %w[remote_work_report gratitude appreciation_for_effort],
    attributes: {
      tone: %w[gentle],
      setting: %w[remote_work home]
    },
    stamps: [
      {
        label: "おはよう〜",
        primary_communication_theme: "greeting_morning",
        communication_themes: %w[remote_work_report],
        attributes: { tone: %w[gentle], setting: %w[remote_work] },
        search_keywords: %w[おはよう 朝 出社]
      },
      {
        label: "お疲れさま！",
        primary_communication_theme: "appreciation_for_effort",
        communication_themes: %w[gratitude],
        attributes: { tone: %w[gentle], setting: %w[remote_work] },
        search_keywords: %w[おつかれ ねぎらい 退勤]
      }
      # ... 8枚すべて記述
    ]
  )
end
```

## 自己点検チェックリスト

PR 作成前に必ず確認:

- [ ] `ruby -c path/to/file.rb` で構文エラーなし
- [ ] 使用した slug がすべてマスタに存在する
- [ ] `seed_id` がファイル名（拡張子なし）と一致
- [ ] **Brand に `research_slug`（起点 Research）が設定されている**
- [ ] **`two_part_definition` が 1 文で入っている**
- [ ] **`character_parts` の 7 部位（eyes / mouth / ears / body / limbs / tail / collar）を記述（持たない部位は空文字）**
- [ ] **`font_spec`（primary / color / outline）が入っている**
- [ ] **`tone_axes` がスコア付き jsonb で入っている**
- [ ] **`target_axes` が入っている**
- [ ] **`identity_axes`（signature / voice / behavior）で他ブランドと混同されない核を埋めた（使わない軸は空でよい）**
- [ ] **`background_color_for_gen` を直接書いていない（モデル固定 #3CB371）**
- [ ] プロンプト系カラムを直接埋めていない（after_commit で生成）
- [ ] 各 stamp に `primary_communication_theme` が1つ設定済み
- [ ] 各 stamp に `search_keywords` が 2〜4 個入っている
- [ ] `purchase_unit_size` が 8/24/40 のいずれか
- [ ] description / concept など日本語フィールドが充実している
- [ ] 1 PR に seed ファイルは 1 つだけ
```

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
