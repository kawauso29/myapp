# 14. 一括実装 Issue(単一PR想定、SD ルート削除後の最終版)

Copilot Coding Agent に **一気に作らせる** ための単一 Issue。
**Stable Diffusion 自動生成ルートは採用しない**。Designer + 管理画面アップロード が唯一の本番ルート。

---

## Issue タイトル

```
[linestamp] LINEスタンプ工房 サブシステム一括構築(Designer + mini_magick 手動運用)
```

## ラベル

`linestamp`, `feature`, `large`

## Assignees

`Copilot`

---

## Issue 本文

```markdown
@copilot

myapp に LINEスタンプ工房サブシステムを **一括** で実装してください。
Phase 分割や複数 PR は不要、可能な限り1つの PR で完結させてください。

## 採用しないもの(重要)

**Stable Diffusion 自動生成は採用しません。**
画像は原田さんが Copilot Chat の Designer で生成 → 管理画面からアップロードします。
Rails は以下を担当:
- 企画 md → プロンプト合成 → 管理画面で表示
- 緑背景画像のアップロードを受け、mini_magick で透過 + LINE規格化
- すでに透過済の画像は直接受け入れ
- LINE申請用 zip ダウンロード提供

## 設計書

すべての仕様は `docs/linestamp/` 配下にあります。**着手前に全て読んでください**:

1. `docs/linestamp/01_ARCHITECTURE.md` — 全体像
2. `docs/linestamp/02_DB_SCHEMA.md` — マイグレーション完全コード(SD関連は除外)
3. `docs/linestamp/03_MODELS.md` — モデル + AASM 完全コード(Generation 除外)
4. `docs/linestamp/04_SERVICES.md` — サービスの完全コード(StableDiffusionClient 除外)
5. `docs/linestamp/05_JOBS.md` — ジョブ完全コード(SD系3つ除外)
6. `docs/linestamp/06_ADMIN_UI.md` — 管理画面 ERB
7. `docs/linestamp/07_GITHUB_WORKFLOWS.md` — Actions YAML
8. `docs/linestamp/08_PLANNING_GUIDE.md` — Copilot 用 skill
9. `docs/linestamp/09_BRAND_FORMAT_SPEC.md` — mdファイル仕様
10. `docs/linestamp/10_PAST_INCIDENTS.md` — 過去事故・対策
11. `docs/linestamp/12_REVIEW_AND_GAPS.md` — **必読**: 設計レビューと補強
12. `docs/linestamp/15_MANUAL_ROUTE_FALLBACK.md` — **必読**: Manual ルート詳細

## 作成・変更すべきファイル一覧

### Gemfile / 依存
- `Gemfile` に追加(既存にあればバージョン確認のみ):
  - `aasm` (状態管理)
  - `mini_magick` (透過処理、必須)
  - `image_processing` (mini_magick 上位ラッパ、オプション)
  - `slack-ruby-client` (Slack files.upload 用)
  - `kaminari` (ページネーション)
- `bundle install`
- (ActiveStorage が未導入なら) `bin/rails active_storage:install`

### DB マイグレーション(5本)
- `db/migrate/*_create_linestamp_researches.rb`
- `db/migrate/*_create_linestamp_brands.rb`
- `db/migrate/*_create_linestamp_packs.rb` (approver_id 含む、12 F-1)
- `db/migrate/*_create_linestamp_stamps.rb`
- `db/migrate/*_create_linestamp_submissions.rb`
- `db/migrate/*_add_admin_to_users.rb` (12 A-1、未存在のみ)

**削除/作成しない**: `linestamp_generations` テーブル(SD 試行履歴用だった、不要)
**削除/作成しない**: `linestamp_brands.generation_mode` 列(常に manual のため)

### モデル(5本、Generation 除外)
- `app/models/linestamp.rb` (namespace 宣言)
- `app/models/linestamp/research.rb`
- `app/models/linestamp/brand.rb` (AASM: planned → prompt_ready → base_ready)
- `app/models/linestamp/pack.rb` (AASM, B-1 ガード補強, B-3 Submission auto-create, F-1 approver)
- `app/models/linestamp/stamp.rb` (AASM)
- `app/models/linestamp/submission.rb` (AASM)

**作らない**: `app/models/linestamp/generation.rb`

### サービス(SD client 除外)
- `app/services/linestamp/prompt_composer.rb`
- `app/services/linestamp/chroma_key_processor.rb` (mini_magick)
- `app/services/linestamp/slack_notifier.rb`
- `app/services/linestamp/brand_sources_syncer.rb`
- `app/services/linestamp/seeders/nemuinu.rb`
- `app/services/linestamp/line_exporter.rb` (12 D-2、申請用 zip)

**作らない**: `app/services/linestamp/stable_diffusion_client.rb`

### ジョブ(SD系3本 除外)
- `app/jobs/linestamp/daily_orchestrator_job.rb` (15 の最終版)
- `app/jobs/linestamp/compose_brand_prompt_job.rb`
- `app/jobs/linestamp/compose_pack_sheet_prompt_job.rb`
- `app/jobs/linestamp/compose_stamp_prompts_job.rb`
- `app/jobs/linestamp/process_stamp_image_job.rb`
- `app/jobs/linestamp/sync_brand_sources_job.rb`

**作らない**:
- `generate_brand_base_image_job.rb`
- `generate_pack_sheet_image_job.rb`
- `generate_stamp_image_job.rb`

### 既存ファイル変更
- `app/jobs/application_job.rb` (12 E-3: Linestamp::* job の Slack エラー通知 rescue)
- `config/sidekiq.yml` (linestamp_default, linestamp_compose, linestamp_process キュー)
- `config/schedule.yml` (linestamp_daily_orchestrator 毎朝8時)
- `config/database.yml` (12 C-2: pool を 20)
- `config/routes.rb` (admin + webhook 追加)

**変更不要**: SD関連の sidekiq キューやcron(linestamp_generate キューも不要)

### 管理画面 (ERB)
- `app/controllers/admin_controller.rb` (12 A-1/A-2、未存在のみ)
- `app/controllers/admin/linestamp/dashboard_controller.rb`
- `app/controllers/admin/linestamp/brands_controller.rb` (15 の `upload_base`/`purge_base`/`toggle_mode` のうち**toggle_modeは不要**)
- `app/controllers/admin/linestamp/packs_controller.rb` (`upload_sheet`, `export_for_line` 等含む)
- `app/controllers/admin/linestamp/stamps_controller.rb` (`upload_raw`/`upload_processed`/`process`/`reset` 含む、`generate` は**不要**)
- `app/controllers/admin/linestamp/researches_controller.rb`
- `app/controllers/admin/linestamp/submissions_controller.rb`
- `app/controllers/linestamp/webhooks_controller.rb`
- `app/views/layouts/admin.html.erb` (Tailwind CDN)
- `app/views/admin/linestamp/dashboard/index.html.erb`
- `app/views/admin/linestamp/brands/index.html.erb`
- `app/views/admin/linestamp/brands/show.html.erb` (プロンプト表示+コピー、base_image アップロード)
- `app/views/admin/linestamp/packs/index.html.erb`
- `app/views/admin/linestamp/packs/show.html.erb` (プロンプト表示+コピー、sheet_image アップロード、承認、export)
- `app/views/admin/linestamp/stamps/show.html.erb` (プロンプト表示+コピー、raw/processed アップロード、再透過)
- `app/views/admin/linestamp/researches/index.html.erb`
- `app/views/admin/linestamp/researches/show.html.erb`
- `app/views/admin/linestamp/submissions/index.html.erb`

### GitHub Actions
- `.github/workflows/linestamp-research.yml` (週次)
- `.github/workflows/linestamp-brand-planning.yml` (日3)
- `.github/workflows/linestamp-pack-planning.yml` (日10)
- `.github/workflows/linestamp-sync.yml` (push 時)
- `.github/ISSUE_TEMPLATE/linestamp-research.md`
- `.github/ISSUE_TEMPLATE/linestamp-brand-planning.md`
- `.github/ISSUE_TEMPLATE/linestamp-pack-planning.md`

全ての workflow で `runs-on: [self-hosted, sakura-vps]`

### Rake タスク
- `lib/tasks/linestamp.rake`
  - `linestamp:sync` — brand_sources/ → DB sync
  - `linestamp:seed_nemuinu` — ねむ犬 seed(画像つき)

### brand_sources/ 初期配置
- `brand_sources/README.md`
- `brand_sources/_templates/*` (5テンプレ)
- `brand_sources/nemuinu/meta.yml`
- `brand_sources/nemuinu/01_brand_theme.md`
- `brand_sources/nemuinu/02_base.md`
- `brand_sources/nemuinu/packs/pack_001/03_stamp_pack.md`
- `brand_sources/nemuinu/packs/pack_001/manifest.yml`

(中身は別途、原田さんから引継ぎ資産で渡す)

### テスト
- `spec/models/linestamp/` 配下に5モデル分
- `spec/services/linestamp/` 配下に各サービス(SD除外)
- `spec/jobs/linestamp/` 配下に主要ジョブ
- `spec/fixtures/linestamp/stamp_01_green.png` (テスト用緑背景画像、原田さんから提供)

### ドキュメント
- `docs/linestamp/` 配下は **すでに配置済み**。触らない。

### 削除すべきもの
- `scripts/transparency_pipeline.py` がもしあれば削除(Pythonは使わない)

## 環境変数(.env.example に追加)

```bash
# Slack 通知
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...
SLACK_BOT_TOKEN=xoxb-...
SLACK_DEFAULT_CHANNEL=#linestamp-bot

# brand_sources 同期 webhook
LINESTAMP_SYNC_TOKEN=(rails secret で生成)
```

**Stable Diffusion 関連の ENV は不要**(`SD_WEBUI_ENDPOINT` 等は追加しない)。

## 設計遵守事項(必読)

- **table_name_prefix** は必ず `linestamp_`
- **過去事故対策**(10_PAST_INCIDENTS.md):
  - 透過アルゴリズム: mini_magick fuzz 25%(緑だけ抜く)
  - キャラ揺れ対策: 個別生成プロンプトには Pack のシート画像を参照するよう明示(プロンプト本文内、実物添付は手動)
  - 漢字崩れ: ネガティブ要素・再生成方針はプロンプトに明記
- **Rails管理思想**: プロンプト本文は md ソース、Service は読んで合成
- **冪等性**: 全 Job は再実行で結果が壊れない

## State machine(SD 削除後の確定版)

### Brand
```
planned → prompt_ready → base_ready
```
- prompt_ready: ComposeBrandPromptJob で base_prompt 合成完了
- base_ready: 管理画面で base_image アップロード完了

### Pack
```
planned → prompt_ready → sheet_ready → stamps_generating → complete
```
- prompt_ready: ComposePackSheetPromptJob + ComposeStampPromptsJob 完了
- sheet_ready: 承認済 + sheet_image アップロード完了
- stamps_generating: 個別 stamp が順次 processed になっていく状態
- complete: 全 stamps が processed(B-1 ガード: stamps.any? && all?(&:processed?))

### Stamp
```
planned → prompt_ready → raw_ready → processed
                       ↘ processed (直接アップロード)
```
- prompt_ready: ComposeStampPromptsJob 完了
- raw_ready: 緑背景画像 attach 完了
- processed: ProcessStampImageJob 完了 or processed_image 直接 attach

### Submission
```
drafting → submitted → approved → selling
                    ↘ rejected
```

## CI
- 既存の `.github/workflows/ci.yml` は変更しない
- 新ジョブの SidekiqWeb mount で衝突しないか確認
- RSpec 全件通過

## 完了条件(チェックリスト)

### 機能
- [ ] `rails db:migrate` 成功(linestamp_* 5テーブル + admin列)
- [ ] `rails runner 'Linestamp::Brand.create!(...)'` でレコード作成可
- [ ] `rake linestamp:sync` で brand_sources/ から DB に同期
- [ ] `rake linestamp:seed_nemuinu` でねむ犬データ投入(画像含む)
- [ ] `/admin/linestamp` で KPI 表示
- [ ] `/admin/linestamp/brands/:id` でプロンプト表示+コピー+base_image アップロード可
- [ ] `/admin/linestamp/packs/:id` でプロンプト表示+コピー+sheet_image アップロード+承認可
- [ ] `/admin/linestamp/packs/:id/export_for_line` で zip ダウンロード
- [ ] `/admin/linestamp/packs/:id/stamps/:id` でプロンプト+raw/processed アップロード可
- [ ] raw_image アップロード → 自動で ProcessStampImageJob 起動
- [ ] processed_image 直接アップロード → 透過処理スキップ、state="processed"
- [ ] `/admin/sidekiq` で Sidekiq Web が見える
- [ ] GitHub Actions の 4 workflow 登録、workflow_dispatch で起動可
- [ ] webhook が token 認証で動く
- [ ] Slack notification(simple webhook)通る
- [ ] Sidekiq cron で daily_orchestrator 登録

### コード品質
- [ ] RuboCop pass
- [ ] RSpec all green
- [ ] CI(既存)壊れない
- [ ] 各 AASM 遷移にガード
- [ ] mini_magick の動作確認テストつき(fixture画像で透過検証)

### ドキュメント
- [ ] PR description にスクショ(管理画面)
- [ ] PR description に「動作確認手順」3〜5行
- [ ] CHANGELOG.md に linestamp サブシステム追加の旨

## やらないこと(スコープ外)

- **Stable Diffusion 関連の全て**(本プロジェクトでは採用しない)
- LINE 申請 API 自動化(LINE 公開 API なし)
- React Native 側の改修(API mode は触らない)
- Stripe / 既存機能の変更

## 質問・ブロッカー

不明点は PR description にコメント。独断で別ファイル/別ディレクトリを作らない。

## 想定 PR サイズ

- 新規ファイル: 約 55 個(SD系を除外したため減少)
- 変更ファイル: 約 5 個
- 行数: 約 4000〜6000 行

大規模 PR を許容してください。
```

---

## Issue 投入コマンド(参考)

```bash
gh issue create \
  --title "[linestamp] LINEスタンプ工房 一括構築" \
  --label linestamp,feature,large \
  --assignee Copilot \
  --body-file docs/linestamp/14_SINGLE_ISSUE_BODY.md
```

(本文は 「## Issue 本文」セクションをコピーして `14_SINGLE_ISSUE_BODY.md` として保存)
