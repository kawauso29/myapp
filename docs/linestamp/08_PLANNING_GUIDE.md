# 08. PLANNING_GUIDE (Copilot Coding Agent 用 "skill" 本体)

> このファイルは Copilot Coding Agent が brand_sources/ 配下のファイルを生成する際の **振る舞い規定**。
> Rails の中の「Cowork skill ファイル」に相当する。GitHub Issue から呼ばれた Copilot がこれを読んで動く。

---

## ミッション全体像

このリポジトリは LINEスタンプの **創作パイプライン** を運営している。
4階層の創作プロセスがあり、各階層の md ファイルを Copilot Coding Agent が生成する:

| 階層 | 出力先 | 1回あたり | 頻度 |
|---|---|---|---|
| Research | `brand_sources/research/{YYYY-WNN}/` | 1セット | 週1 |
| Brand | `brand_sources/{brand_slug}/` | 1ブランド | 日3 |
| Pack | `brand_sources/{brand_slug}/packs/{pack_slug}/` | 1パック | 日10 |
| (Stamp の画像生成は Rails が自動) | | | |

Copilot は Issue 内の指示を読み、適切な階層のファイルを生成して **PR を出す**。
レビュー(原田さん)→ マージ後、Rails が DB に sync する。

---

## 共通厳守事項

### 1. ファイル配置を厳守
- 指示された絶対パスにのみ書く
- 既存ファイルの上書きはしない(slug を変える)
- `brand_sources/_templates/` は読み取り専用テンプレート

### 2. お手本を必ず参照
- Brand 企画前: `brand_sources/nemuinu/01_brand_theme.md` 必読
- Pack 企画前: `brand_sources/nemuinu/packs/pack_001/03_stamp_pack.md` 必読
- 文体・粒度・章立てを踏襲

### 3. 過去事故を踏まえる
`docs/linestamp/PAST_INCIDENTS.md` を必ず確認。

### 4. ファイル仕様準拠
`docs/linestamp/BRAND_FORMAT_SPEC.md` の仕様に従う。

### 5. PR 形式
- Draft PR で出す
- description にコンセプト要約(3行以内)
- 1 PR = 1 ブランド or 1 Pack(複数を1PRに混ぜない)

---

## 調査 (Research)

### ミッション
LINEスタンプ企画の源泉となる調査を週次で実施する。市場・季節・感情・世代ニーズを抽出。

### 出力ファイル

```
brand_sources/research/{YYYY-WNN}/
├── findings.md    ← 本文(調査結果)
├── trends.yml     ← 構造化キーワード
└── brief.md       ← 調査依頼(Issue 本文をコピー)
```

### findings.md の構成

```markdown
# 週次調査 {YYYY-WNN}

## 1. LINEスタンプ市場の動向
- (公開情報・トレンド調査)

## 2. 季節・イベント要因
- 今月の祝日・季節要素
- 来月以降の祝日・季節要素

## 3. 利用シーン(最低5つ)
- シーン1: (説明)
- シーン2: ...

## 4. 感情ニーズ(最低3つ)
- (例: 「申し訳なさを和らげる」「会議の合間に送れる」)

## 5. ターゲット世代別の好み
- 20代: ...
- 30代: ...

## 6. 企画ヒント
- (この調査から派生しうるブランド方向性 2〜3案)
```

### trends.yml の構造

```yaml
keywords:
  - 在宅ワーク
  - 雨の日
  - 朝活
seasons:
  - 梅雨
  - 初夏
emotions:
  - 気まずさ
  - ねぎらい
  - ぼんやり
age_groups:
  - 20s
  - 30s
  - 40s
notes: |
  (補足、自由記述)
```

### 制約
- 引用元 URL は本文中に書く(Copilot が見たページ)
- 推測には「(推測)」と明記
- 「絶対」「必ず」のような断定は避ける

---

## Brand 企画

### ミッション
新規 LINE スタンプブランド(=キャラ+世界観)を1つ企画する。

### 入力
- 最新の `brand_sources/research/{latest}/findings.md` と `trends.yml`
- お手本 `brand_sources/nemuinu/`

### 出力ファイル

```
brand_sources/{slug}/
├── 01_brand_theme.md
├── 02_base.md
└── meta.yml
```

### slug のルール
- 英小文字 + 数字 + アンダースコア(`^[a-z][a-z0-9_]*$`)
- 既存と重複しない
- キャラ名から自然に派生(例: ねむ犬 → nemuinu)

### meta.yml

```yaml
series_name: "在宅ワークのゆる犬"     # 世界観・シリーズ大名称
character_name: "ねむ犬"              # キャラ単体の名前
research_slug: "2026-W21"              # 元となった調査(任意)
target_age: ["20s", "30s"]
core_emotion: "ねむそうな気まずさ"
```

### 01_brand_theme.md の構成(ねむ犬を踏襲)

```markdown
# 01_brand_theme.md

## ブランドテーマ

### シリーズ名
{series_name}

### キャラクター名
{character_name}

---

## ブランドの最重要定義

{キャラ名} は「○○」ではない。

**{キャラ名}は、▼▼な△△である。**  ← 二段定義(必須)

---

## 優先順位(最重要)

### 1. {属性1}(最優先)
- 具体的特徴1
- 具体的特徴2

### 2. {属性2}
- ...

### 3. {属性3}
- ...

※ 優先順位は3つまで

---

## NGになりやすいズレ

### NG1: ...
- 細かい説明

### NG2: ...

---

## OKな方向

- 具体例
- 具体例

---

## 表現レイヤー

### Core Layer(必須)
- 必ず守る描画ルール

### Work Layer
- 基本パックで使う要素

### Dream Layer
- 将来の派生パックで使える要素

---

## 一言

「{キャラの本質を一文で}」
```

### 02_base.md の構成

```markdown
# 02_base.md

## 強化ポイント

今回の修正目的:
👉 ...
👉 ...

---

## 最重要ルール(キャラ)

{キャラの絶対遵守}

---

## 最重要ルール(文字)

日本語の文字は **正しい漢字で丁寧に描くこと**。
- 漢字を崩さない
- ひらがなに逃げない

---

## 顔ルール
- 目: ...
- 口: ...

---

## NG例 / OK例
...

---

## 強制プロンプト

\`\`\`text
{画像生成AIに渡す直接プロンプト本文}
\`\`\`
```

### Brand 企画の手順

1. 最新 research を読む
2. trends から **1つの感情キーワード**を選ぶ(例: 「気まずさ」)
3. それを表現するキャラ案を3つブレインストーミング(コメントとして PR description に残す)
4. ベストを1つ選んで slug 確定
5. 二段定義を書く(これが核)
6. ねむ犬の章立てに従って 01_brand_theme.md / 02_base.md / meta.yml を埋める

### よくある失敗
- 二段定義が「××な△△」のみ(○○ではない、が抜ける) → 必ず2文に
- キャラ仕様が抽象的 → 線の太さ・色・表情まで明示
- NG/OK 例が抽象的 → 具体的に

---

## Pack 企画

### ミッション
既存ブランドに新シリーズ(パック)を1つ企画する。1パック = 8枚スタンプ。

### 入力
- 対象ブランドの `01_brand_theme.md` / `02_base.md` (必読)
- 既存 packs/* (重複回避)

### 出力ファイル

```
brand_sources/{brand_slug}/packs/{pack_slug}/
├── 03_stamp_pack.md
└── manifest.yml
```

### pack_slug のルール
- ブランド内でユニーク
- 内容を表す(例: `pack_001`, `dreamy_sleep`, `weekend_relax`)
- 既存 pack と重複しない

### manifest.yml(機械可読、重要)

```yaml
series_theme: "在宅ワーク基本"
layer: "core_work"   # core_work / dream / weekend / seasonal etc.
stamps:
  - number: 1
    label: "いま仕事中だよ"
    situation: "PC前で作業。ノートPCを覗き込んでいる。半目・無表情。"
  - number: 2
    label: "あとで返すね"
    situation: "スマホを片手で見ながら。半目・気まずい。汗マーク一滴。"
  # ... 全8件
```

#### label のルール
- LINEスタンプの定番文字数(5〜10文字)
- 漢字は読みやすいものを優先
- 既存パックと重複しない

#### situation のルール
- 1〜2文で具体的に
- ポーズ・表情・小道具・装飾を明示
- 「半目」「白フチ」等のキャラ仕様は brand_theme から踏襲

### 03_stamp_pack.md の構成

```markdown
# 03_stamp_pack.md

## このパックのコンセプト
{series_theme} 。... (3行で説明)

## 表現レイヤー
{Core / Work / Dream } のうち今回採用

## 採用しない要素(派生パックへ)
- 今回は採用しないが、Dream Layer 派生パックで使う候補
- ...

## 個別書き出しルール
- 1画像1スタンプ
- 文字は中央上部に配置
- パックシート画像を必ず参照(揺れ防止)
```

### Pack 企画の手順

1. ブランドの brand_theme と base を必読
2. 既存 packs の series_theme をチェック(重複回避)
3. このパックの **コンセプト1文** を決める
4. 8枚の利用シーンを思いつく順に書き出し、整理
5. label と situation を仕上げる
6. manifest.yml と 03_stamp_pack.md を書く

### よくある失敗
- 8枚のテーマがバラバラ(統一感なし)
- label が長すぎ / 既存と重複
- situation が抽象的(「楽しそう」だけ等)
- 既存パックと series_theme が被る

---

## 自己点検チェックリスト(全企画共通)

PR を出す前に Copilot 自身が確認:

- [ ] 指示されたパスにのみファイルを作成した
- [ ] お手本(nemuinu)を読んだ
- [ ] PAST_INCIDENTS.md の事故を踏まえた
- [ ] BRAND_FORMAT_SPEC.md の仕様に従った
- [ ] 既存と重複していない(slug, label, series_theme)
- [ ] 文体が既存ブランドと揃っている
- [ ] PR description に企画概要を書いた

不安があれば draft 状態を維持し、Issue に質問コメントを残す。

---

## 期待されない振る舞い

- 画像生成は **しない**(Rails 側の責務)
- 既存ファイルの大幅書き換えは **しない**(別 Issue で扱う)
- 著作権を侵害する固有名詞は使わない(ディズニー、サンリオ等の既存IP)
- 性的・暴力的・差別的な表現は禁止
- ファイルの新規作成は brand_sources/ 以下のみ(他ディレクトリは触らない)

---

## 質問があるときの動き方

- PR description で `@原田さん 質問:` 形式で書く
- ブロッカーがあれば Issue にコメントを残して draft 状態のままに
- 自己解決できる範囲は **過去ブランド を参照** して埋める
