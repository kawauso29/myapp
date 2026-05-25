# 11. ~~Issues Backlog(Phase分割版)~~ — **【廃止】**

> **このファイルは Phase 分割の参考用です。実際には `14_SINGLE_ISSUE.md` を採用します。**
> また内容に **SD ルート関連の Issue が含まれていますが、SDは不採用となりました**(15_MANUAL_ROUTE_FALLBACK 参照)。
>
> 採用する Issue: `14_SINGLE_ISSUE.md`(SD削除済の単一巨大Issue)
>
> 以下は歴史的経緯として残す。

---

## ~~Phase分割版~~ (使わない)

各 Issue は Copilot Coding Agent にアサインして PR を出させる単位で粒度を切ってあるが、
**現在は一括 Issue 方式に統一**(14_SINGLE_ISSUE.md)。

---

## Phase 1: 基盤(DB / Models / Storage)

### Issue #1: gem 追加 + ActiveStorage 初期化

**ラベル**: `linestamp`, `phase-1`, `setup`

```markdown
@copilot

myapp に LINEスタンプ工房サブシステムを追加するための基盤を整える。

## 作業
1. Gemfile に以下を追加(既存にある場合はバージョン整合性のみ確認):
   - `gem 'aasm'`
   - `gem 'mini_magick'`
   - `gem 'image_processing'`
   - `gem 'slack-ruby-client'`
   - (sidekiq-cron は既存にあればそのまま)
2. `bundle install`
3. ActiveStorage が未導入なら `bin/rails active_storage:install`
4. `app/models/linestamp.rb` に namespace モジュール宣言
   ```ruby
   module Linestamp
     def self.table_name_prefix = "linestamp_"
   end
   ```

## 仕様
docs/linestamp/01_ARCHITECTURE.md 参照

## 完了条件
- [ ] Gemfile.lock が更新されている
- [ ] `bundle exec rails runner 'p Linestamp.table_name_prefix'` で linestamp_ が出る
- [ ] CI(RSpec + RuboCop)が通る
```

### Issue #2: DBマイグレーション(6テーブル)

**ラベル**: `linestamp`, `phase-1`, `db`

```markdown
@copilot

LINEスタンプ工房の DB スキーマを作成。

## 作業
6つのマイグレーションファイルを作成 → `db:migrate`:

1. CreateLinestampResearches
2. CreateLinestampBrands
3. CreateLinestampPacks
4. CreateLinestampStamps
5. CreateLinestampGenerations
6. CreateLinestampSubmissions

## 仕様
docs/linestamp/02_DB_SCHEMA.md に完全な定義あり。そのままコピーで OK。

## 完了条件
- [ ] `bundle exec rails db:migrate` 成功
- [ ] `db/schema.rb` に linestamp_* テーブルが反映
- [ ] CI(マイグレーション含む)が通る
```

### Issue #3: Model 一式 + AASM

**ラベル**: `linestamp`, `phase-1`, `model`

```markdown
@copilot

6モデルとAASM定義を作成。

## 作業
1. `app/models/linestamp.rb`(namespace)
2. `app/models/linestamp/research.rb`
3. `app/models/linestamp/brand.rb` (AASM)
4. `app/models/linestamp/pack.rb` (AASM)
5. `app/models/linestamp/stamp.rb` (AASM)
6. `app/models/linestamp/generation.rb`
7. `app/models/linestamp/submission.rb` (AASM)

## 仕様
docs/linestamp/03_MODELS.md に完全なコードあり。そのままコピー。

## テスト
spec/models/linestamp/ 配下に各モデルの spec(バリデーション + AASM 遷移)

## 完了条件
- [ ] 6モデル + テスト一式
- [ ] CI(RSpec)が通る
```

---

## Phase 2: 企画レイヤー(brand_sources + GitHub Actions)

### Issue #4: brand_sources/ 初期構造とテンプレート

**ラベル**: `linestamp`, `phase-2`, `planning`

```markdown
@copilot

`brand_sources/` を初期化、テンプレートと nemuinu(空殻)を配置。

## 作業
1. `brand_sources/README.md` を作成(用途説明)
2. `brand_sources/_templates/` 配下にテンプレ4本配置:
   - 01_brand_theme.template.md
   - 02_base.template.md
   - 03_stamp_pack.template.md
   - manifest.template.yml
   - meta.template.yml
3. nemuinu の **md 一式** だけ配置(画像は Phase 6 で別途)
   - brand_sources/nemuinu/01_brand_theme.md
   - brand_sources/nemuinu/02_base.md
   - brand_sources/nemuinu/meta.yml
   - brand_sources/nemuinu/packs/pack_001/03_stamp_pack.md
   - brand_sources/nemuinu/packs/pack_001/manifest.yml

## 仕様
docs/linestamp/09_BRAND_FORMAT_SPEC.md
ねむ犬の元データは(別途、原田さんが渡す)

## 完了条件
- [ ] ディレクトリ構造が仕様通り
- [ ] _templates/ にテンプレ4本
- [ ] nemuinu に必須mdが揃う
```

### Issue #5: PLANNING_GUIDE 等の docs 配置

**ラベル**: `linestamp`, `phase-2`, `docs`

```markdown
@copilot

docs/linestamp/ にCopilot Coding Agent 用の guide を配置。

## 作業
1. docs/linestamp/PLANNING_GUIDE.md
2. docs/linestamp/BRAND_FORMAT_SPEC.md
3. docs/linestamp/PAST_INCIDENTS.md

## 仕様
それぞれ 08_PLANNING_GUIDE.md / 09_BRAND_FORMAT_SPEC.md / 10_PAST_INCIDENTS.md の内容を配置。

## 完了条件
- [ ] 3ファイルが揃う
- [ ] Markdownリンタ通過
```

### Issue #6: GitHub Actions 3本(企画 workflow)

**ラベル**: `linestamp`, `phase-2`, `ci`

```markdown
@copilot

GitHub Actions の企画 workflow を3本追加。runner は self-hosted。

## 作業
1. .github/workflows/linestamp-research.yml
2. .github/workflows/linestamp-brand-planning.yml
3. .github/workflows/linestamp-pack-planning.yml
4. .github/ISSUE_TEMPLATE/linestamp-research.md
5. .github/ISSUE_TEMPLATE/linestamp-brand-planning.md
6. .github/ISSUE_TEMPLATE/linestamp-pack-planning.md

## 仕様
docs/linestamp/07_GITHUB_WORKFLOWS.md にそのまま使えるYAMLあり。
全 workflow で `runs-on: self-hosted`

## 完了条件
- [ ] workflow_dispatch で手動実行できる
- [ ] schedule cron が設定されている
- [ ] Copilot に Issue がアサインされることを workflow_dispatch で実機確認
```

---

## Phase 3: 生成レイヤー(SD / mini_magick / Slack)

### Issue #7: PromptComposer サービス

**ラベル**: `linestamp`, `phase-3`, `service`

```markdown
@copilot

mdソースから SD 用プロンプトを合成するサービス。

## 作業
app/services/linestamp/prompt_composer.rb を作成

## 仕様
docs/linestamp/04_SERVICES.md の 「2. PromptComposer」セクション参照。
3メソッド: `compose_for_brand_base`, `compose_for_pack_sheet`, `compose_for_stamp`

## テスト
spec/services/linestamp/prompt_composer_spec.rb
- nemuinu のmdソースを fixture として使い、各 compose_xxx の出力検証

## 完了条件
- [ ] 3メソッド実装
- [ ] negative_prompt も別メソッドで取得可能
- [ ] テスト通過
```

### Issue #8: StableDiffusionClient サービス

**ラベル**: `linestamp`, `phase-3`, `service`

```markdown
@copilot

AUTOMATIC1111 WebUI と通信するクライアント。

## 作業
app/services/linestamp/stable_diffusion_client.rb

## 仕様
docs/linestamp/04_SERVICES.md の「3. StableDiffusionClient」
- txt2img / img2img / healthcheck

## テスト
spec/services/linestamp/stable_diffusion_client_spec.rb (webmock)

## 完了条件
- [ ] 3メソッド実装
- [ ] webmock でリクエスト形式テスト通過
- [ ] ENV['SD_WEBUI_ENDPOINT'] でURL切替可
```

### Issue #9: ChromaKeyProcessor サービス (mini_magick)

**ラベル**: `linestamp`, `phase-3`, `service`

```markdown
@copilot

緑背景を透過、LINE規格(370×320)へ整形。

## 作業
app/services/linestamp/chroma_key_processor.rb

## 仕様
docs/linestamp/04_SERVICES.md の「4. ChromaKeyProcessor (mini_magick)」
- fuzz 25%, スピル抑制 0.85, LINE_W/H/MARGIN 定数

## テスト
spec/services/linestamp/chroma_key_processor_spec.rb
- spec/fixtures/linestamp/stamp_01_green.png (ねむ犬の緑背景画像)を入力
- 出力が 370×320, アルファチャンネルあり, 白ピクセル(体)が残ることを検証

## 完了条件
- [ ] 入出力動作
- [ ] サイズ 370×320 確認
- [ ] 白ピクセルが残ることをテストで検証
```

### Issue #10: SlackNotifier サービス

**ラベル**: `linestamp`, `phase-3`, `service`

```markdown
@copilot

Slack Webhook 通知 + ファイルアップロード。

## 作業
app/services/linestamp/slack_notifier.rb

## 仕様
docs/linestamp/04_SERVICES.md の「5. SlackNotifier」
- notify (webhook 単純通知)
- notify_stamp_completed (画像つき)
- notify_daily_summary
- upload_image (Slack Bot Token 必須)

## テスト
spec/services/linestamp/slack_notifier_spec.rb (webmock)

## 完了条件
- [ ] 4メソッド実装、webmock 通過
```

### Issue #11: Sidekiq ジョブ一式(8ジョブ)

**ラベル**: `linestamp`, `phase-3`, `job`

```markdown
@copilot

ジョブ一式を実装。各ジョブは状態遷移とエラーハンドル込み。

## 作業
app/jobs/linestamp/ 配下に8ジョブ:

1. daily_orchestrator_job.rb
2. compose_brand_prompt_job.rb
3. compose_pack_sheet_prompt_job.rb
4. compose_stamp_prompts_job.rb
5. generate_brand_base_image_job.rb
6. generate_pack_sheet_image_job.rb
7. generate_stamp_image_job.rb
8. process_stamp_image_job.rb

## 仕様
docs/linestamp/05_JOBS.md にそのまま使えるコードあり。

## 設定
- config/sidekiq.yml に linestamp 用キューを追加
- config/schedule.yml に linestamp_daily_orchestrator を追加(cron "0 8 * * *")

## テスト
spec/jobs/linestamp/ 配下に各ジョブの spec
- 状態遷移のテスト
- 外部 API (SD) はモック

## 完了条件
- [ ] 8ジョブ実装
- [ ] sidekiq.yml と schedule.yml 設定
- [ ] CI 通過
```

### Issue #12: BrandSourcesSyncer + Webhook

**ラベル**: `linestamp`, `phase-3`, `service`, `controller`

```markdown
@copilot

brand_sources/ → DB sync の核となるサービスと、トリガー webhook。

## 作業
1. app/services/linestamp/brand_sources_syncer.rb
2. app/controllers/linestamp/webhooks_controller.rb
3. app/jobs/linestamp/sync_brand_sources_job.rb
4. config/routes.rb に webhook と admin namespace 追加
5. lib/tasks/linestamp.rake (sync, seed_nemuinu)

## 仕様
docs/linestamp/04_SERVICES.md の「1. BrandSourcesSyncer」
docs/linestamp/06_ADMIN_UI.md の「Webhook Controller」

## 完了条件
- [ ] rake linestamp:sync が動く
- [ ] curl で webhook が叩ける(Token 認証つき)
- [ ] nemuinu の md が DB に反映される(画像はまだ)
```

---

## Phase 4: 管理画面

### Issue #13: AdminController 基盤 + Dashboard

**ラベル**: `linestamp`, `phase-4`, `admin`

```markdown
@copilot

管理画面の認証基盤と Dashboard ページ。

## 作業
1. app/controllers/admin_controller.rb(未存在なら作成、admin ロール確認)
2. app/controllers/admin/linestamp/dashboard_controller.rb
3. app/views/layouts/admin.html.erb(Tailwind CDN)
4. app/views/admin/linestamp/dashboard/index.html.erb

## 仕様
docs/linestamp/06_ADMIN_UI.md「1. DashboardController」「Dashboard」「CSS」

## 完了条件
- [ ] /admin/linestamp にアクセス可
- [ ] 非adminは弾かれる
- [ ] KPI が表示される
```

### Issue #14: Pack 一覧 + 承認チェックボックス

**ラベル**: `linestamp`, `phase-4`, `admin`

```markdown
@copilot

Pack の承認 UI。

## 作業
1. app/controllers/admin/linestamp/packs_controller.rb
2. app/views/admin/linestamp/packs/index.html.erb
3. app/views/admin/linestamp/packs/show.html.erb
4. routes.rb の patch :approve / patch :unapprove

## 仕様
docs/linestamp/06_ADMIN_UI.md「PacksController」「Pack 一覧」「Pack 詳細」

## 完了条件
- [ ] Pack 一覧から1クリックで承認/解除
- [ ] 承認状態が DB に保存
- [ ] approved な Pack が緑ハイライト
```

### Issue #15: Stamp 詳細 + 再生成

**ラベル**: `linestamp`, `phase-4`, `admin`

```markdown
@copilot

個別 Stamp の表示と再生成トリガ。

## 作業
1. app/controllers/admin/linestamp/stamps_controller.rb (show, retry)
2. app/views/admin/linestamp/stamps/show.html.erb (画像 + メタ表示)

## 仕様
docs/linestamp/06_ADMIN_UI.md「StampsController」

## 完了条件
- [ ] processed_image / raw_image / 状態が見える
- [ ] 「再生成」ボタンで GenerateStampImageJob が起動
```

---

## Phase 5: E2E

### Issue #16: nemuinu seed (画像つき)

**ラベル**: `linestamp`, `phase-5`, `seed`

```markdown
@copilot

ねむ犬の既存画像資産を取り込み、DBとActiveStorageに反映。

## 作業
1. app/services/linestamp/seeders/nemuinu.rb
2. (原田さんから渡された)nemuinu の画像群を brand_sources/nemuinu/ 配下に配置
3. lib/tasks/linestamp.rake に seed_nemuinu タスク追加

## 完了条件
- [ ] `rake linestamp:seed_nemuinu` で nemuinu Brand と pack_001 + 8 stamps が DB と画像で揃う
- [ ] /admin/linestamp で nemuinu / pack_001 の画像が表示される
```

### Issue #17: 手動 E2E 動作確認(workflow_dispatch)

**ラベル**: `linestamp`, `phase-5`, `e2e`

```markdown
@copilot ではなく、これは原田さん用の手順書 Issue。

## 確認手順
1. AUTOMATIC1111 WebUI を起動(`--api` 付き)
2. self-hosted runner 起動
3. linestamp-pack-planning.yml を workflow_dispatch 実行
4. Copilot が PR を出すか確認
5. PR をマージ
6. linestamp-sync.yml が発火、Rails 側に同期
7. /admin/linestamp/packs で新Packを確認、承認チェック
8. 翌朝 8時の daily_orchestrator を待つ(or 手動で `bundle exec rails runner "Linestamp::DailyOrchestratorJob.perform_now"`)
9. SD 生成 → 透過 → Slack 通知 完了確認
```

---

## 依存関係グラフ

```
Phase 1
  #1 (gem)
   └─ #2 (db) ── #3 (model)

Phase 2 (並列可)
  #4 (brand_sources)
  #5 (docs)
  #6 (workflows)

Phase 3 (一部並列)
  #7 (PromptComposer) ─┐
  #8 (SDClient) ─────┐ │
  #9 (ChromaKey) ────┼─┼─→ #11 (Jobs)
  #10 (Slack) ───────┘ │
                       │
  #12 (Sync) ──────────┘

Phase 4 (Phase 3 と並列可)
  #13 (Dashboard) ── #14 (Pack UI) ── #15 (Stamp UI)

Phase 5
  #16 (seed) → #17 (E2E確認)
```

---

## 全体スケジュール目安

| Phase | 想定工数 |
|---|---|
| Phase 1 | Copilot 1日(レビュー込み) |
| Phase 2 | 1日 |
| Phase 3 | 2〜3日 |
| Phase 4 | 1〜2日 |
| Phase 5 | 1日 |

トータル **約1週間** で全パイプライン稼働。

---

## 起動時の Issue 起票テンプレート

各 Issue を立てる際は `gh` CLI を使うと楽:

```bash
gh issue create \
  --title "[linestamp/#1] gem 追加 + ActiveStorage 初期化" \
  --label linestamp,phase-1,setup \
  --assignee Copilot \
  --body-file docs/linestamp/issues/01.md
```

(`docs/linestamp/issues/` に各 issue 本文を md として置いておくと便利)
