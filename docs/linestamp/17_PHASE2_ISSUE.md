# 17. Phase 2 修正 Issue(Copilot Coding Agent 投入用)

Phase 1 実装(PR マージ済)に対する **構造的な修正PR** を作らせる。

---

## Issue タイトル

```
[linestamp/phase2] ブランド情報の構造化・参照画像同梱・PromptComposer書き直し
```

## ラベル

`linestamp`, `feature`, `large`, `phase2`

## Assignees

`Copilot`

---

## Issue 本文(コピペ用)

```markdown
@copilot

Phase 1 実装(`docs/linestamp/` 配下の設計に基づく)を読み直したところ、
**設計の根幹が抜け落ちている** ことが判明しました。具体的なギャップと修正内容は:

→ `docs/linestamp/16_PHASE2_GAPS_AND_FIXES.md` を必ず最初に読んでください。

## ミッション

Phase 1 で作った Linestamp サブシステムに、以下の **構造化・参照画像同梱・PromptComposer書き直し** を一括で適用します。
別PRや分割は不要、可能な限り1 PR で完結させてください。

## 重要事項

- **既存テーブルは drop しない**。すべて `add_column` / `add_reference` で拡張する。
- ★ **旧カラム(`brand.name`, `pack.title`, `stamp.emotion`, `stamp.text_overlay`)は本PRで完全削除する**。
  1. 新カラム追加(本PR Sprint A)
  2. データ backfill(旧→新へコピー、`update_columns` で冪等)
  3. 全コード参照を新カラムに置換
  4. 旧カラム drop マイグレーション
  この順で1PR内で完結させる。
- ★ **`pack.main_image` (240×240) と `pack.tab_image` (96×74) は実生成まで通す**(テーブル準備のみで終わらせない)。
  - 手動アップロード経路
  - 既存 stamp.processed_image から自動生成する `PackRepresentativeImageGenerator` サービス
  - LineExporter zip に `main.png` / `tab.png` 同梱
- 既存テストは壊さないこと。新カラムには対応する spec を追加。
- 旧カラム削除後、旧カラム参照していた spec は新カラム参照に書き換える。

## 作業項目

### 1. 新規マイグレーション(10本)

詳細は `docs/linestamp/16_PHASE2_GAPS_AND_FIXES.md` の Sprint A / F / G 参照。

実行順:
1. `create_linestamp_image_specs` (新規テーブル)
2. `add_structured_fields_to_linestamp_brands`
3. `add_structured_fields_to_linestamp_packs`
4. `add_structured_fields_to_linestamp_stamps`
5. `add_structured_fields_to_linestamp_researches`
6. `add_representative_stamps_to_linestamp_packs` (main/tab_source_stamp_id, Sprint F-2)
7. `seed_default_image_specs` (data migration, LINE規格3種を入れる)
8. `backfill_legacy_columns_to_structured_fields` (data migration, Sprint G-2)
9. `migrate_existing_data_to_structured_fields` (data migration, 既存 brand/pack/stamp の text/jsonb を新カラムへ移し替え)
10. `drop_legacy_columns_from_linestamp_tables` (Sprint G-4。旧カラム削除)

#### linestamp_image_specs 初期 seed

| slug | name | width | height | margin_px | active |
|---|---|---|---|---|---|
| line_main_370x320 | LINE メインスタンプ(横長) | 370 | 320 | 10 | true |
| line_main_240x240 | LINE メインスタンプ(正方形) | 240 | 240 | 10 | false |
| line_tab_96x74 | LINE タブ画像 | 96 | 74 | 4 | false |

#### Brand 追加カラム

- `two_part_definition` text — 「○○ではない、○○な△△」
- `concept` text
- `target_audience` text
- `target_axes` jsonb — `{age, gender, occupation, lifestyle}`
- `tone_axes` jsonb — `{gentle, cute, funny, innovative, neat, warm, edgy}` 各 0.0〜1.0
- `purpose_background` text
- `character_parts` jsonb — `{eyes, mouth, ears, body, limbs, tail, collar}`
- `font_spec` jsonb — `{primary, secondary, color, outline, ...}`
- `primary_color` string default "#FFFFFF"
- `background_color_for_gen` string default "#3CB371"

#### Pack 追加カラム

- `slug` string
- `series_theme` string
- `layer` string — "core_work" / "dream" / "weekend" / "seasonal" / "event"
- `world_view` text
- `usage_scenes` jsonb default []
- `target_emotions` jsonb default []
- `excluded_elements` text — 「採用しない要素(派生パックへの含み)」
- `image_spec_id` references linestamp_image_specs (default: line_main_370x320)
- unique index `[brand_id, slug]`

#### Stamp 追加カラム

- `label` string — 既存 text_overlay と並行(text_overlay は深い意味の保管用、label は LINE 表示文言)
- `situation` text
- `intent` text — 送信意図(申し訳なさ / ねぎらい / 話題転換)
- `usage_scene` text
- `search_keywords` jsonb default []
- `communication_purpose` text — コミュニケーション代替の意図
- `pose_spec` text
- `props` text

#### Research 追加カラム

- `slug` string unique — "2026-W21"
- `target_axes` jsonb
- `tone_axes` jsonb
- `seasons` jsonb default []
- `emotions` jsonb default []
- `usage_scenes` jsonb default []
- `keywords` jsonb default []
- `findings` text
- `brand_ideas` text
- `line_market_insights` text
- `communication_substitute_needs` text

### 2. Model 拡張

各モデルに新カラムの validation・delegate・helper を追加。

#### Linestamp::Brand

```ruby
validates :background_color_for_gen, format: { with: /\A#[0-9A-Fa-f]{6}\z/ }

def tone_axes_radar  # 管理画面のレーダーチャート用
  %w[gentle cute funny innovative neat warm edgy].map { |k| [k, (tone_axes[k] || 0.0).to_f] }
end

def designer_kit_components
  {
    brand_prompt: brand_prompt,
    base_image: base_image,
    character_parts: character_parts,
    font_spec: font_spec,
    two_part_definition: two_part_definition
  }
end
```

#### Linestamp::Pack

```ruby
belongs_to :image_spec, class_name: "Linestamp::ImageSpec", optional: true
delegate :width, :height, :margin_px, to: :image_spec, allow_nil: true, prefix: true

def effective_image_spec
  image_spec || Linestamp::ImageSpec.find_by!(slug: "line_main_370x320")
end
```

#### Linestamp::ImageSpec (新規)

```ruby
module Linestamp
  class ImageSpec < ApplicationRecord
    self.table_name = "linestamp_image_specs"
    has_many :packs, foreign_key: :image_spec_id
    validates :slug, presence: true, uniqueness: true
    scope :active, -> { where(active: true) }
  end
end
```

### 3. PromptComposer 全面書き直し

`docs/linestamp/16_PHASE2_GAPS_AND_FIXES.md` Sprint B-1 / B-2 / B-3 のコードに置き換えてください。

特に重要なポイント:

- **`compose_brand_prompt`** は「12構図 × 3フォント基準シート」を必ず要求
- **`compose_pack_sheet_prompt`** は brand.base_image を参照画像として明示
- **`compose_stamp_prompt`** は brand.base_image と pack.sheet_image の両方を参照画像として明示
- 既存の `BRAND_TEMPLATE` / `PACK_SHEET_TEMPLATE` / `STAMP_TEMPLATE` 定数はそのまま削除して新仕様に置き換え

既存 spec(`spec/services/linestamp/prompt_composer_spec.rb`)は **新仕様に合わせて書き直す**。

### 4. Designer Kit サービス追加(新規)

`docs/linestamp/16_PHASE2_GAPS_AND_FIXES.md` Sprint C-4 参照。

ファイル:
- `app/services/linestamp/designer_kit/brand.rb`
- `app/services/linestamp/designer_kit/pack.rb`
- `app/services/linestamp/designer_kit/stamp.rb`

各々 `#zip` メソッドで以下を含む zip を生成:
- `prompt.txt` (該当階層のプロンプト)
- `README.md` (Designer 投入手順)
- `references/brand_base.png` (該当時)
- `references/pack_sheet.png` (該当時 / stamp の場合のみ)

### 5. 管理画面 UI 強化

#### Brand show
- 二段定義を H2 で大きく表示
- character_parts を表で展開表示
- font_spec を見やすい形式で表示
- tone_axes をプログレスバー風に表示
- 「📥 Designer Kit DL」ボタン追加 → `download_kit_admin_linestamp_brand_path`

#### Pack show
- 既存 brand.base_image をサイドカラムで表示(参照画像として常時見える)
- world_view / usage_scenes / target_emotions / excluded_elements の構造化表示
- 「📥 Designer Kit DL」ボタン追加

#### Stamp show(最重要)
- **brand.base_image と pack.sheet_image を両方表示**(常時参照可能)
- situation / intent / usage_scene / search_keywords / pose_spec / props の構造化表示
- 「📥 Designer Kit DL」ボタン追加 → zip 1個に prompt + 参照画像2枚 を同梱

### 6. ルート追加

```ruby
namespace :admin do
  namespace :linestamp do
    resources :brands do
      member do
        # ... 既存
        get :download_kit  # Designer Kit zip
      end
    end
    resources :packs do
      member do
        # ... 既存
        get :download_kit
      end
    end
    resources :stamps do
      member do
        # ... 既存
        get :download_kit
      end
    end
  end
end
```

### 7. brand_sources/nemuinu 復元

現状の `brand_sources/nemuinu/` 配下は **引継ぎ仕様と乖離している**。
正しい中身に置き換える(原田さんから提供される `nemuinu_full_handover_bundle.zip` を参照):

- `01_brand_theme.md` — 二段定義 + 優先順位3つ + 表現レイヤー Core/Work/Dream を含む完全版
- `02_base.md` — 強制プロンプト + 顔ルール + 文字ルール(漢字崩れ対策)を含む完全版
- `packs/pack_001/manifest.yml` — slug, series_theme, layer, world_view, usage_scenes, target_emotions, excluded_elements, 各 stamp に situation/intent/usage_scene/pose_spec/props/search_keywords/communication_purpose を含む
- `packs/pack_001/03_stamp_pack.md` — パック固有ルールを記述

引継ぎ資料は `docs/linestamp/10_PAST_INCIDENTS.md` と `docs/linestamp/09_BRAND_FORMAT_SPEC.md` を再読することで構造が分かる。

### 8. BrandSourcesSyncer 拡張

manifest.yml の新フィールドを Stamp / Pack / Brand に sync するロジックを追加。
既存 `body_text` を新カラムに分割するパース処理を追加。

旧カラム削除に合わせて、旧フィールド名(`text` / `emotion`)を読む処理は削除し、新フィールド名のみ参照する:
- manifest.yml の `label` / `intent` / `situation` / `usage_scene` / `pose_spec` / `props` / `search_keywords` / `communication_purpose`
- meta.yml の `series_name` / `character_name` / `two_part_definition` / `character_parts` / `font_spec` / `tone_axes`

### 8B. PackRepresentativeImageGenerator サービス新規(Sprint F-4)

`app/services/linestamp/pack_representative_image_generator.rb` を新規作成。

`docs/linestamp/16_PHASE2_GAPS_AND_FIXES.md` Sprint F-4 のコードに従う。
- `:main` (line_main_240x240) と `:tab` (line_tab_96x74) の2モード
- source_stamp.processed_image を読み込み、image_spec に従ってリサイズして pack.main_image / tab_image に attach
- `pack.main_source_stamp_id` / `tab_source_stamp_id` を記録

### 8C. ChromaKeyProcessor の image_spec 対応(Sprint F-3)

既存の `Linestamp::ChromaKeyProcessor#call(input_path)` を
`call(input_path, spec: nil)` シグネチャに変更。spec から width/height/margin_px を取る。
spec 指定なしの場合は `line_main_370x320` をデフォルトに。

### 8D. Pack 詳細 UI に main_image / tab_image 操作追加(Sprint F-5)

Pack show 画面に2セクション追加:
- main_image (240×240) — 手動アップロード + 「stamp #N から自動生成」フォーム
- tab_image (96×74) — 同上

### 8E. ルート追加(Sprint F-6)

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

### 8F. LineExporter 拡張(Sprint F-7)

zip に `main.png` と `tab.png` も含める。

### 8G. Pack 完了判定(Sprint F-8)

`event :complete_all` の guard を以下に変更:
```ruby
guard: ->(pack) {
  pack.stamps.any? &&
  pack.stamps.all?(&:processed?) &&
  pack.main_image.attached? &&
  pack.tab_image.attached?
}
```

### 8H. ★ Planning workflow の中身を実装(現状 TODO スタブ)

Phase 1 で作られた以下の workflow は **`echo "TODO..."` の空殻** のため、手動実行しても Issue が起票されません。
中身を実装してください。詳細は `docs/linestamp/16_PHASE2_GAPS_AND_FIXES.md` Sprint H 参照。

書き換える workflow:
- `.github/workflows/linestamp-research.yml` (週1 + workflow_dispatch)
- `.github/workflows/linestamp-brand-planning.yml` (日次 + workflow_dispatch, count input)
- `.github/workflows/linestamp-pack-planning.yml` (日次 + workflow_dispatch, count input)
- `.github/workflows/linestamp-sync.yml` (brand_sources push 時、Rails webhook を叩く)

必須要件(myapp の既存運用パターン、CLAUDE.md 準拠):
- **`DEPLOY_TOKEN` (個人 PAT) を使う**(GITHUB_TOKEN だと Copilot Coding Agent が反応しない GitHub 仕様)
- **Issue 作成 → `@copilot` メンションコメント → `copilot-swe-agent[bot]` をアサイン** の順
- 既存の `ai_sns_plan.yml` 等と同じ作法

新たに必要な Secret:
- `LINESTAMP_SYNC_TOKEN` (rails secret で生成、Rails の webhook 認証に使う)

### 9. 緑色を統一

`#00FF00` の出現箇所を全て `#3CB371` (medium sea green) に変更:
- ChromaKeyProcessor で `transparent "green"` の挙動を確認
- brand.background_color_for_gen のデフォルト
- view 側のサンプル背景色
- 02_base.md の記述

過去事故 #1 対策(fuzz 25% で白い体を守る)は不変。

### 10. テスト追加・更新

- 新マイグレーション → 既存 spec が壊れないこと確認
- PromptComposer 新仕様の spec
- DesignerKit の spec
- 管理画面: Designer Kit ダウンロードリクエスト spec
- Brand の tone_axes_radar / character_parts validation spec

## 完了条件

### スキーマ
- [ ] `linestamp_image_specs` テーブルが存在し、3 行 seed されている(active: true は line_main_370x320 / line_main_240x240 / line_tab_96x74)
- [ ] Brand / Pack / Stamp / Research に新カラムが追加されている
- [ ] 既存ねむ犬データが新カラムに正しく移行されている(backfill 済)
- [ ] **旧カラム(`brand.name`, `pack.title`, `stamp.emotion`, `stamp.text_overlay`)が drop されている**
- [ ] `Pack#main_source_stamp_id` / `tab_source_stamp_id` の参照が存在する

### PromptComposer
- [ ] `compose_brand_prompt` が「12構図 + 3フォント基準シート」を要求している
- [ ] `compose_pack_sheet_prompt` が brand.base_image 参照を明示している
- [ ] `compose_stamp_prompt` が brand.base_image と pack.sheet_image の両方参照を明示している
- [ ] spec が緑

### 管理画面
- [ ] Brand 詳細で character_parts / tone_axes / font_spec が見える
- [ ] Pack 詳細で brand.base_image がサイドに見える
- [ ] **Stamp 詳細で brand.base_image と pack.sheet_image が両方見える**
- [ ] 「Designer Kit DL」が Brand / Pack / Stamp 各々で動く
- [ ] DL した zip に prompt.txt + README.md + references/ が含まれている
- [ ] **Pack 詳細で main_image (240×240) のアップロード/自動生成が動く**
- [ ] **Pack 詳細で tab_image (96×74) のアップロード/自動生成が動く**
- [ ] **LineExporter zip に `main.png` と `tab.png` が含まれる**
- [ ] **Pack の `complete_all` が main/tab 揃わないと発火しない**

### brand_sources
- [ ] `brand_sources/nemuinu/01_brand_theme.md` に二段定義が含まれる
- [ ] `brand_sources/nemuinu/02_base.md` に強制プロンプトが含まれる
- [ ] `manifest.yml` に situation/intent/usage_scene/pose_spec/props/search_keywords が含まれる(全8件)

### 色
- [ ] `#00FF00` の能動的使用が無い(grep で出ない)
- [ ] `#3CB371` または `brand.background_color_for_gen` 経由に統一

### 旧カラム削除
- [ ] `grep -r 'brand\.name'` で能動的参照ゼロ(`character_name` / `series_name` に置換)
- [ ] `grep -r 'pack\.title'` で能動的参照ゼロ(`series_theme` に置換)
- [ ] `grep -r 'stamp\.emotion'` で能動的参照ゼロ(`intent` に置換)
- [ ] `grep -r 'stamp\.text_overlay'` で能動的参照ゼロ(`label` に置換)
- [ ] db/schema.rb から該当4カラムが消えている

### Planning workflow (Sprint H)
- [ ] `linestamp-research.yml` を workflow_dispatch で手動実行 → 実際に Issue が作られて Copilot がアサインされる
- [ ] `linestamp-brand-planning.yml` を count=1 で実行 → ブランド企画 Issue が1件作られる
- [ ] `linestamp-pack-planning.yml` を count=1 で実行 → パック企画 Issue が1件作られる
- [ ] `linestamp-sync.yml` が brand_sources/ への push で発火する
- [ ] すべての workflow が `DEPLOY_TOKEN` を使用している(GITHUB_TOKEN ではない)
- [ ] Issue 作成後に `copilot-swe-agent[bot]` がアサインされている

### CI
- [ ] RSpec all green
- [ ] RuboCop pass
- [ ] 既存テスト(linestamp 以外含む)壊れない

## スコープ外

- ControlNet / LoRA など SD 系の話 — 採用しない方針継続
- LINE 申請 API 自動化 — LINE 公開 API なし、手動運用継続
- React Native 側の改修

(旧カラム削除 / main_image・tab_image 実生成は本 Phase に **含む** ← 前 Issue から変更)

## ヒント

- migration の generator は `bin/rails generate data_migration <name>` を使うと冪等テンプレが出る(CLAUDE.md の「データ migration ガイド」参照)
- 既存テーブルへの `add_column` は冪等性のため、`add_column :linestamp_brands, :two_part_definition, :text, if_not_exists: true` のように書くと安全(Rails 7+)
- 引継ぎ資料の md は zip 内の `nemuinu_full_handover_bundle.zip` を原田さんから別途受け取って `brand_sources/nemuinu/` に展開する

## 想定 PR サイズ

- 新規マイグレーション 10 本
- Brand/Pack/Stamp/Research/ImageSpec のモデル拡張
- PromptComposer 全面書き直し
- DesignerKit 3 サービス新規
- PackRepresentativeImageGenerator 新規(main/tab実生成)
- ChromaKeyProcessor の image_spec 対応
- LineExporter 拡張(main.png/tab.png 同梱)
- 管理画面 view 3 ページ強化 + Pack 詳細に main/tab 操作追加
- brand_sources/nemuinu 4ファイル書き直し
- 全view/controller/service/spec での旧カラム参照を新カラムに置換
- **企画 workflow 4本の中身実装(現状 TODO スタブ、DEPLOY_TOKEN + Copilot アサイン込み)**
- 約 3500〜5500 行
```

---

## 投入コマンド

```bash
gh issue create \
  --title "[linestamp/phase2] ブランド情報の構造化・参照画像同梱・PromptComposer書き直し" \
  --label linestamp,feature,large,phase2 \
  --assignee Copilot \
  --body-file docs/linestamp/17_PHASE2_ISSUE_BODY.md
```

(本文は本ファイルの「## Issue 本文(コピペ用)」を `17_PHASE2_ISSUE_BODY.md` として保存)
