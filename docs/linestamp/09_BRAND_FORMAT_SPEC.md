# 09. brand_sources/ ファイル仕様

`brand_sources/` 配下に置く md / yml ファイルの仕様を定義する。  
Copilot Coding Agent と Rails の `BrandSourcesSyncer` の両者が読む契約書。

---

## ディレクトリ構造(全体)

```
brand_sources/
├── README.md                                   ← 人間が読む案内
├── _templates/                                  ← 雛形(編集禁止、Copilotが参照)
│   ├── 01_brand_theme.template.md
│   ├── 02_base.template.md
│   ├── 03_stamp_pack.template.md
│   ├── manifest.template.yml
│   └── meta.template.yml
├── research/
│   └── {YYYY-WNN}/
│       ├── findings.md
│       ├── trends.yml
│       └── brief.md
└── {brand_slug}/
    ├── 01_brand_theme.md
    ├── 02_base.md
    ├── meta.yml
    └── packs/
        └── {pack_slug}/
            ├── 03_stamp_pack.md
            └── manifest.yml
```

---

## ファイル仕様詳細

### 1. `research/{slug}/brief.md`

調査依頼テキスト。Issue 本文をそのままコピー。

```markdown
# 依頼内容
{Issue 本文をコピペ}
```

### 2. `research/{slug}/findings.md`

調査結果本文。フォーマット自由だが下記章立て推奨:

```markdown
# 週次調査 {YYYY-WNN}

## 1. LINEスタンプ市場の動向
## 2. 季節・イベント要因
## 3. 利用シーン
## 4. 感情ニーズ
## 5. ターゲット世代別の好み
## 6. 企画ヒント
```

### 3. `research/{slug}/trends.yml`

構造化キーワード抽出。Rails の `Research#trends` (jsonb) にそのままロード。

```yaml
keywords:        # 必須、配列
  - 在宅ワーク
  - 雨の日
seasons:         # 必須、配列
  - 梅雨
emotions:        # 必須、配列
  - 気まずさ
  - ねぎらい
age_groups:      # 必須、配列
  - 20s
  - 30s
notes: |         # 任意、文字列
  自由記述
```

### 4. `{brand_slug}/meta.yml`

ブランド機械可読メタ。Rails が `Brand` レコードに反映。

```yaml
series_name:     "在宅ワークのゆる犬"      # 必須(Brand#series_name)
character_name:  "ねむ犬"                  # 必須(Brand#character_name)
research_slug:   "2026-W21"                 # 任意(Brand#research)
target_age:                                 # 任意(Brand#metadata 配下)
  - 20s
  - 30s
core_emotion:    "ねむそうな気まずさ"      # 任意(Brand#metadata 配下)
notes: |
  自由記述
```

### 5. `{brand_slug}/01_brand_theme.md`

ブランドテーマ。**Rails の `Brand#brand_theme_md` に丸ごと保存**される。

必須セクション(プロンプト合成で抽出される):
- `## ブランドの最重要定義`(二段定義)
- `## 優先順位`(3つ)
- `## 表現レイヤー`(Core/Work/Dream)
- `## OKな方向`(PromptComposer がこのセクションを抽出)
- `## NGになりやすいズレ`

### 6. `{brand_slug}/02_base.md`

ベース仕様。**Rails の `Brand#base_md` に丸ごと保存**。

必須セクション:
- `## 最重要ルール(キャラ)`
- `## 最重要ルール(文字)`
- `## 顔ルール`
- `## 強制プロンプト`(PromptComposer がこのセクションを抽出)

### 7. `{brand_slug}/packs/{pack_slug}/manifest.yml`

8枚スタンプの機械可読定義。**最重要ファイル**(Rails が Pack と Stamp を作成する元)。

```yaml
series_theme: "在宅ワーク基本"     # 必須(Pack#series_theme)
layer: "core_work"                  # 必須(Pack#layer)
                                    # 値の候補: core_work / dream / weekend / seasonal / event / mood
stamps:                             # 必須、ちょうど8件
  - number: 1                       # 必須、1..8 連番
    label: "いま仕事中だよ"          # 必須、5〜10文字推奨
    situation: "PC前で作業。半目。" # 必須、1〜2文
  - number: 2
    label: "あとで返すね"
    situation: "スマホ片手、汗マーク一滴"
  # ... 8件まで
```

#### バリデーション
- `stamps` の長さは必ず 8
- `number` は 1..8 の重複なし
- `label` は1〜30文字
- `situation` は1〜200文字

### 8. `{brand_slug}/packs/{pack_slug}/03_stamp_pack.md`

パック固有ルール。**Rails の `Pack#pack_md` に丸ごと保存**。

```markdown
# 03_stamp_pack.md

## このパックのコンセプト
{1〜3行で}

## 表現レイヤー
このパックでは Core + Work Layer を使用、Dream Layer は採用しない

## 採用しない要素(派生パックへの含み)
- 雲・星(Dream Layer 派生で採用予定)

## 個別書き出しルール
- 1画像1スタンプ
- 文字は中央上部
- パックシートを必ず参照
```

---

## slug の命名規約

| 種別 | パターン | 例 |
|---|---|---|
| Research slug | `\d{4}-W\d{2}` | `2026-W21` |
| Brand slug | `[a-z][a-z0-9_]*` | `nemuinu`, `shaki_neko` |
| Pack slug | `[a-z][a-z0-9_]*` | `pack_001`, `dreamy_sleep` |

---

## _templates/ の中身(参考)

### `_templates/manifest.template.yml`

```yaml
# このファイルは brand_sources/_templates/manifest.template.yml の雛形
# Copilot Coding Agent が新規 Pack 企画時にコピーして埋める

series_theme: ""        # 例: 在宅ワーク基本
layer: "core_work"      # core_work | dream | weekend | seasonal | event | mood
stamps:
  - number: 1
    label: ""
    situation: ""
  - number: 2
    label: ""
    situation: ""
  - number: 3
    label: ""
    situation: ""
  - number: 4
    label: ""
    situation: ""
  - number: 5
    label: ""
    situation: ""
  - number: 6
    label: ""
    situation: ""
  - number: 7
    label: ""
    situation: ""
  - number: 8
    label: ""
    situation: ""
```

### `_templates/meta.template.yml`

```yaml
series_name: ""
character_name: ""
research_slug: ""
target_age: []
core_emotion: ""
notes: ""
```

### `_templates/01_brand_theme.template.md`

```markdown
# 01_brand_theme.md

## ブランドテーマ

### シリーズ名
{series_name}

### キャラクター名
{character_name}

---

## ブランドの最重要定義

{character_name} は「{NOT-THIS}」ではない。

**{character_name}は、{描写}な{属性}である。**

---

## 優先順位(最重要)

### 1. {ATTR1}(最優先)
- ...

### 2. {ATTR2}
- ...

### 3. {ATTR3}
- ...

---

## NGになりやすいズレ
- ...

## OKな方向
- ...

---

## 表現レイヤー

### Core Layer(必須)
- ...

### Work Layer
- ...

### Dream Layer
- ...

---

## 一言

「{一文}」
```

(02_base, 03_stamp_pack も同様の雛形)

---

## バリデーション(Rails 側で実装)

`BrandSourcesSyncer` が読み込み時に下記をチェック、失敗したらレコード作成しない(ログのみ):

| ファイル | チェック |
|---|---|
| meta.yml | series_name, character_name が必須・空でない |
| 01_brand_theme.md | 「ブランドの最重要定義」セクションが存在 |
| 02_base.md | 「強制プロンプト」セクションが存在 |
| manifest.yml | stamps が 8件、number 重複なし、label 全て空でない |
| trends.yml | keywords/seasons/emotions/age_groups の少なくとも1配列が存在 |

エラー時の挙動:
- 該当ファイルだけスキップ、他は処理続行
- Slack に warn 通知

---

## ファイルの真実性

| 場面 | 真実の源 |
|---|---|
| 企画内容 | git の md ファイル |
| Rails の state | DB |
| 生成画像 | ActiveStorage |
| 過去履歴 | git log |

→ **mdソースを編集した後 sync すれば DB の brand_theme_md/base_md/pack_md は上書きされる**。プロンプト再合成も次回 daily orchestrator で走る。
