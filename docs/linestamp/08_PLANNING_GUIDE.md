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

リサーチは市場調査の結果を DB に保存するもの。

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

ブランドは「キャラクター + 世界観」の単位。

```ruby
Linestamp::Importer.run(seed_id: "2026-05-26-120000_brand_nemuinu") do
  brand = upsert_brand!(
    slug: "nemuinu",
    character_name: "ねむ犬",
    series_name: "ねむ犬スタンプ",
    persona_name: "ねむ犬",
    concept: "いつも眠そうだけど仕事はきっちりこなす柴犬",
    target_audience: "20-30代 在宅ワーカー",
    description: "ゆるい表情で日常のコミュニケーションを柔らかくする",
    primary_color: "#F5DEB3",
    background_color_for_gen: "#3CB371"
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
        attributes: { tone: %w[gentle], setting: %w[remote_work] }
      },
      {
        label: "お疲れさま！",
        primary_communication_theme: "appreciation_for_effort",
        communication_themes: %w[gratitude],
        attributes: { tone: %w[gentle], setting: %w[remote_work] }
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
- [ ] 各 stamp に `primary_communication_theme` が1つ設定済み
- [ ] `purchase_unit_size` が 8/24/40 のいずれか
- [ ] description / concept など日本語フィールドが充実している
- [ ] 1 PR に seed ファイルは 1 つだけ
