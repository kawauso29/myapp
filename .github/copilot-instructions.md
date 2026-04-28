# GitHub Copilot Instructions

**回答は必ず日本語で行うこと。**

このリポジトリは Ruby on Rails 8.1 + Expo (React Native Web) のフルスタックアプリです。
以下のルールを必ず守ってコードを生成・修正してください。

## プロジェクト概要

- **バックエンド**: Ruby 3.3.7 / Rails 8.1.2
- **フロントエンド**: Expo (React Native Web) / TypeScript
- **DB**: PostgreSQL（本番: myapp_production）
- **キャッシュ/キュー**: Redis + Solid Queue
- **本番サーバー**: さくらVPS（Ubuntu 22.04 / Nginx + Puma）

## ドキュメント連動更新ルール

- `.github/copilot-instructions.md` と `CLAUDE.md` は連動ドキュメントとして扱う
- 運用ルールを更新したら、**必ず両方を同時に更新**する
- 片方だけ更新した場合は、同じ変更をもう片方にも反映して整合性を保つ

## 進行中プロジェクト

AI エージェント間の認識統一のため、進行中のプロジェクトを以下で管理する。
作業前に必ず該当ドキュメントの「現状」と「TODO」を確認すること。

| プロジェクト | ドキュメント | 状態 |
|---|---|---|
| GitHub Actions 自前移行（self-hosted runner） | `docs/projects/github-actions-migration.md` | ✅ 完了（build_frontend以外は全て移行済み。copilot-setup-steps.yml/pr_guardrails.yml も self-hosted 化完了） |
| 運営 OS Phase 30〜41 実装 | `docs/projects/operating-spec-phase-30-plan.md` | ✅ 完了（Phase 30〜44 完了。Phase 44 で DB化・heartbeat駆動・組織ロールマスタ・enforce ON を実装済み） |
| Ledger V2 移行（v1 反省を踏まえた最小 Kernel 構築） | `docs/projects/ledger-v2-migration.md`（設計の正本は `ledger_v2_detailed_design.txt`） | 🔧 進行中（法典 + 引き継ぎ準備フェーズ。Ticket 1〜18 未着手。**v1 自動化機構を v2 構築に流用しない**・**1 PR 1 機能 1 テスト**・**機構安定まで自動マージ一時停止**（安定後は自動マージ・自動デプロイへ移行）を厳守） |

## コーディングルール（Ruby / Rails）

### やってはいけないこと（CIで必ず引っかかる）

- `Time.now` は使わない → **`Time.current`** を使う（Rails/TimeZone cop）
- `"str" + method()` の文字列結合は使わない → **`"str#{method()}"`** 補間を使う
- `head :unauthorized and return` は使わない → **`return head :unauthorized`** を使う
- private ブロック内に定数を定義しない → **private より前に定義する**
- `actions/checkout@v6` は存在しない → **`@v4`** を使う
- `enum :status, { pending: 0 }, prefix: true` のようにprefixつきenumのスコープ名は **`status_pending`**（`pending` ではない）。specでmockする場合も `receive_message_chain(:status_pending, :count)` のようにprefixつきで書く
- `line-bot-api` 2.7 には `Line::Bot::Client` が存在しない → `Line::Bot::V2::MessagingApi::ApiClient` と `*_with_http_info` を使う。job spec では `expect_any_instance_of(...).to have_received(...)` は使わず、`LineNotifierService.new` を明示的にstubしたdoubleで検証する
- `Ledgers::ImprovementDetector` のspecで個別ルールの検知件数を1件に固定して検証する場合、`stale_ui_check` ルールの副作用を避けるため `ui_check` の直近開催データを先に作成する（未作成だと `result[:detected]` が +1 される）
- `weekly_pdca.yml` の `WIP_COUNT=$(grep -c ... || echo 0)` は `0\n0` になり GITHUB_OUTPUT 書き込みが `Invalid format '0'` で落ちる → `|| true` + `${WIP_COUNT:-0}` に修正する
- self-hosted runner の CI で `db:test:prepare` だけを実行すると、新規 migration 追加直後に `ActiveRecord::PendingMigrationError` で `job-check` / `route-check` / `test` が同時に落ちることがある → `ci.yml` の各ジョブで `bin/rails db:migrate || bin/rails db:schema:load` の後に `bin/rails db:test:prepare` を実行する。`db:migrate` が `PG::DuplicateTable` 等で失敗した場合は `db:schema:load` にフォールバックしてテストDBを schema.rb から再構築する
- self-hosted runner の CI で PostgreSQL のテストDB（`myapp_test` / `myapp_test_queue`）が未作成だと `db:test:prepare` が `ActiveRecord::NoDatabaseError` で失敗する → `ci.yml` の `job-check` / `route-check` / `test` の先頭で `bin/rails db:create` を実行してから `db:migrate || db:schema:load` と `db:test:prepare` を実行する
- self-hosted runner（sakura-vps）には `jq` が入っていない → self-hosted で動くワークフロー内では `jq` の代わりに `python3 -c "import json, os ..."` で JSON 生成・パースする
- ワークフローで Copilot coding agent にメンションする場合は `@github-copilot` ではなく **`@copilot`** を使う（`@github-copilot` では反応しない）
- `GITHUB_TOKEN` で作成したコメント/Issueは Copilot coding agent の Webhook をトリガーしない（GitHub のループ防止仕様）。`@copilot` メンションを含むコメントは必ず `github-token: ${{ secrets.DEPLOY_TOKEN }}` で投稿する。`DEPLOY_TOKEN` は **fine-grained PAT で `Issues: Read and Write` スコープが必須**。スコープ不足で 403 が出る場合は GitHub Settings → Developer settings → Personal access tokens → DEPLOY_TOKEN を `Issues: Read and Write` で再発行する
- `ai_sns_plan.yml` で `git commit --allow-empty` を使うと空PRが作成され、auto_mergeがCopilot実装前にマージしてしまう → ①`auto_merge.yml` に空PRガード（変更ファイル数チェック）を追加、②PRは `draft: true` で作成、③`--allow-empty` の代わりに実ファイル変更をコミットする
- `ai_sns_plan.yml` で `@copilot` をPR本文（body）に書いても Copilot coding agent は起動しない → PR作成後に `issues.createComment` で別途PRコメントとして `@copilot` メンションを投稿する
- `pr_guardrails.yml` の必須セクション検証を全PR一律にすると、`copilot/ai-sns-*` / `auto-fix/*` / `deploy-failure/*` の自動起票PRが失敗する → 自動運用ブランチは本文テンプレ検証と §31 メタ検証を skip し、通常セッションPRのみ厳格検証する
- `plan_review.yml` でも同様に `@copilot` をIssue本文（body）に書いても起動しない → Issue作成後に `issues.createComment` で別途Issueコメントとして `@copilot` メンションを投稿する（DEPLOY_TOKEN使用）
- `plan_review.yml` の open Issue 重複チェックは7日超の古い Issue を自動クローズしてから新規作成する（Copilot 無反応による永久ブロック防止）
- `weekly_pdca.yml` は `in_progress` 項目の `started_at` が7日以上前なら自動で `todo` にリセットする（WIP 上限永久到達の防止）
- `auto_merge.yml` は計画追加PRマージ後に `plan-review` ラベル付き open Issue を自動クローズする（計画レビューサイクルの循環維持）
- Puma 8.x は `config/puma/{environment}.rb` が存在すると `config/puma.rb` を**読み込まない** → `config/puma/production.rb` に SolidQueue プラグイン設定（`plugin :solid_queue`, `solid_queue_mode :async`）と `.env` ロードを必ず含める
- `config/puma/production.rb` で `workers N`（N>0）を設定するとクラスターモード（fork）になり、SolidQueue async スレッドでジョブクラス解決が失敗する → 単一VPSでは `workers` と `preload_app!` を使わずシングルプロセスモードにする
- デプロイ中の Puma 再起動時に SolidQueue recurring task が `ActiveJob::UnknownJobClassError` で一時的に失敗する → `config/initializers/active_job_unknown_class_retry.rb` で `ActiveJob::Base.deserialize` を prepend し、失敗時に `eager_load!` → リトライする。管理画面 Failed Jobs でクラスがロード可能な一時的失敗は自動 discard する
- `deploy.yml` の `workflow_run` トリガーが self-hosted runner 移行後に発火しなくなった → `ci.yml` に `dispatch_deploy` ジョブを追加し、main の CI 成功後に `deploy.yml` を `workflow_dispatch` で直接起動する（auto_merge.yml と同じ方式）。`deploy.yml` からは `workflow_run` トリガーを廃止済み。`dispatch_deploy` にはリトライロジック（最大3回）を追加済み
- `bin/check_runner_health` の systemd サービス名が実際と不一致 → `./svc.sh install` で作成されるサービス名はホスト名ベース（`actions.runner.kawauso29-myapp.os3-392-29108.service`）。ラベル名（`sakura-vps`）やユーザー名（`ubuntu`）ではない
- **本番で何の通知も来ず recurring も止まる症状は SolidQueue scheduler の無音停止が最有力**。`config/puma/production.rb` の SolidQueue plugin 起動を `if ENV["SOLID_QUEUE_IN_PUMA"]` でガードしていると、`.env` 読み込み失敗で plugin 自体が起動せず scheduler が消え、`MonitorFailedJobsJob`（5分毎）も含む全 recurring が止まり「失敗してても誰も気づかない」状態になる。production.rb は production 専用なので **デフォルト ON / 明示的に `SOLID_QUEUE_IN_PUMA=0` で opt-out** にする。さらに `bin/check_solid_queue_alive`（VPS cron 5分毎）と `solid_queue:diagnose` rake タスクで scheduler 死活を継続監視する
- データ移行だけの migration（DDL変更なし）を追加したときも `db/schema.rb` の `version` は最新 migration 番号に更新される必要がある。schema version を更新せず migration ファイルだけをコミットすると CI の `test` / `job-check` / `route-check` で `ActiveRecord::PendingMigrationError` が発生する
- **Ledger 圧縮時間軸の正本は `Ledgers::TimeAxis::INTERVALS`**（daily=30分 / weekly=4時間 / monthly=12時間 / quarterly=2日 / annual=7日 / long_term=28日）。設計書 §11 の「4 年 = 28 日」圧縮を実装に落としたもの。Runner の `due_date` は `Ledgers::TimeAxis.due_date_for(cadence)`、`idempotency_key` は `Ledgers::IdempotencyKey.for_meeting(..., cadence:)` を必ず使い、`config/recurring.yml` の Ledger 系 cron も圧縮 interval（daily=30m → `*/30 * * * *`、weekly=4h → `0 */4 * * *`、monthly=12h → `0 */12 * * *`、quarterly=2d → `0 6 */2 * *`、annual=7d → `0 8 * * 0`）に揃える（実カレンダー時間で運用すると、1ヶ月＝4年シミュレーション中に quarterly が 0〜1 回しか発火せず、ledger が回らない＝AI SNS の運営 PDCA も止まる）
- **Ledger Runner の cadence チェーン**（carry_over_items）: daily → weekly（hold_items）→ monthly（carry weekly）→ quarterly（carry monthly）→ annual（carry quarterly）。各 Runner は `previous_hold_items` private メソッドで前段の最新 hold_items を取得する
- **daily cadence は「会議なし種別」**（§12.6 選択肢A）: `DailyRunner` は KPI スナップショット取得・異常検知のみ行い、`chair_role: "system"` / `participants: []`。`DailyLedgerRunJob` は 30分周期で recurring.yml から起動
- self-hosted runner の永続DBで `create_table` migration がテーブル既存時に `PG::DuplicateTable` で失敗する → `create_table ... if_not_exists: true` と `add_index ... if_not_exists: true` を使い冪等にする
- `ENFORCE_TEMPLATE=1` / `TicketLedger.enforce_template = true` は `before_create :assert_template_present!` で `template_id` を必須化するが、`template_id` は `GithubMapping::CopilotInputTemplate#generate(ticket)` がチケット保存**後**に付与する設計のため、自動起票系（Runner/Detector/Planner/Feedback::Intake）の `TicketLedger.create!` は `template_id` を設定できず `RecordNotSaved` で落ちる。結果 `MeetingLedger` が `status: :open` のまま滞留し、以降のサイクルがブロックされる。→ Runner 系の自動チケット生成では `skip_template_guard: true` を明示的に渡して guard を bypass する（`QuarterlyReviewRunner` / `AnnualPlanRunner` / `WeeklyDeptRunner#create_ticket!` / `ImprovementDetector#create_ticket!` / `Reinforcements::Planner#create_improvement_ticket!` / `Feedback::Intake#maybe_escalate!`）。回帰テストは `spec/features/ledger_enforce_template_spec.rb`
- Copilot coding agent を Issue から起動するには `@copilot` コメントだけでなく、issueの **assignees に `copilot-swe-agent[bot]` を追加** することが必要。`GithubIssueService.add_assignees(issue_number:, assignees: ['copilot-swe-agent[bot]'], agent_assignment: { target_repo: REPO, base_branch: 'main', custom_instructions: '...' })` を呼ぶ。**`copilot` ではなく `copilot-swe-agent[bot]` が正しいユーザー名**（前者は無視される）。`agent_assignment` パラメータも必須。コメントは assignee 追加の**前**に投稿すること（Copilot はアサイン時点の既存コメントのみ読む）。`DEPLOY_TOKEN` には `Issues: Read and Write` に加えて `Actions: Read and Write`、`Contents: Read and Write`、`Pull requests: Read and Write` も必要。`TicketIssueSync#post_copilot_comment` で実装済み。
- **self-hosted runner OOM キルと自動再起動失敗（2026-04-26 実績）**: Copilot coding agent が `parallel_validation`（CodeQL）実行時に Java プロセスが 1.36GB 消費、1.9GB VPS で OOM キル発生。runner サービスは result: oom-kill で停止。`check_runner_health` の自動再起動も失敗した。**失敗の原因**: `sudo systemctl restart actions.runner...` が sudoers NOPASSWD に未登録のため、cron（TTY なし）から実行するとパスワード要求で失敗する。**2つの対処**:①OOM 再発防止: `$HOME/actions-runner/.env` に `JAVA_TOOL_OPTIONS=-Xmx600m` を追加し Java ヒープ上限を制限（`deploy.yml` の `Setup runner environment` ステップで自動設定）②sudo 権限の一時手動設定（一度だけ実行）: `echo 'ubuntu ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart actions.runner.kawauso29-myapp.os3-392-29108.service, /usr/bin/systemctl reset-failed actions.runner.kawauso29-myapp.os3-392-29108.service, /bin/systemctl restart actions.runner.kawauso29-myapp.os3-392-29108.service, /bin/systemctl reset-failed actions.runner.kawauso29-myapp.os3-392-29108.service' | sudo tee /etc/sudoers.d/github-runner-health && sudo chmod 440 /etc/sudoers.d/github-runner-health`
- **Copilot が `copilot/ai-sns-*` ではなく `copilot/copilotledger-*` ブランチで実装を完了したとき**: `copilot/ai-sns-*` ブランチの PR は変更ファイルが0件の空PRとして残り永久 open になる。plan status も done 更新されない。**対処**: ①`auto_merge.yml` の空PRガード（`merge_on_ci_pass` / `undraft_ai_sns_prs` スケジュール）が空の ai-sns-* PRを自動クローズする（修正済み）。②plan status を本番DBで手動更新: `cd ~/myapp && RAILS_ENV=production bin/rails runner "t = TicketLedger.find_ai_sns_plan_by_item_key('KEY'); t.skip_template_guard=true; t.skip_lane_capacity_guard=true; t.skip_pr_guardrail=true; t.skip_stop_guard=true; t.update!(status: :completed)"`

### メソッド・スタイル

- `redirect_back` の引数はカッコなし: `redirect_back fallback_location: path, notice: "..."` （Ruby 3.3でカッコ＋カンマはSyntaxError）
- Rails の規約に従い、controller は `before_action` でフィルタを定義する

## デプロイ・CI のルール

### ブランチ戦略

1. 作業は必ずフィーチャーブランチ（`claude/...` または `copilot/...`）で行う
2. 作業前に `git branch -a` で重複ブランチがないか確認する
3. CI（scan_ruby / lint / job-check / route-check / test）が全て通ってからマージする
4. マージ後はブランチを削除する（ローカル・リモート両方）

### CI/CD の仕組み

```
main への直接 push
    ↓
[CI ワークフロー] scan_ruby / lint / job-check / route-check / test
    ↓ 全成功                       ↓ 失敗
[dispatch_deploy ジョブ]        [Auto Fix ワークフロー]
  → deploy.yml を dispatch        ↓ rubocop --autocorrect
    ↓                             ↓ 自動修正PR作成 + Slack通知
[Deploy ワークフロー]
  ↓ ヘルスチェック（5回）
  ↓ 失敗 → 自動ロールバック
  ↓ Slack通知

PR の自動マージ（auto_merge.yml）
    ↓
[auto_merge] CI pass → PR マージ → deploy.yml を workflow_dispatch
    ↓                         ↓ [AI SNS計画] PR の場合
[Deploy ワークフロー]       plan_status.yml を done に自動更新 + Slack通知
（上記と同じ）

AI SNS 自動開発サイクル（PDCA）
    ↓
[weekly_pdca.yml] 3時間ごと KPI収集 + WIPチェック + 滞留検知（schedule自動実行）
    ↓ WIP < 2 & todo > 0      ↓ todo ≤ 2             ↓ in_progress > 7日
[ai_sns_plan.yml]         [plan_review.yml]         自動リセット → todo に戻す
  PR作成 → @copilot 実装     Issue起票 → @copilot      + Slack通知
    ↓ CI通過                      ↓ Copilot がPR作成
[auto_merge.yml]              [auto_merge.yml]
  マージ → plan_status done     マージ → 新todo追加 → plan-review Issue 自動クローズ
  → deploy.yml 起動               → 次のPDCAサイクルへ
```

- **デプロイは CI 成功後のみ**: `ci.yml` の `dispatch_deploy` ジョブが main の CI 全成功後に `deploy.yml` を `workflow_dispatch` で直接起動する
- **手動デプロイ**: `workflow_dispatch` でいつでも実行可能
- **auto_merge はマージ成功後に deploy を直接 dispatch する**: GITHUB_TOKEN によるマージでは push イベントが発火せず CI→deploy の連鎖が起きないため、`workflow_dispatch` で deploy.yml を直接起動する
- **自動処理が止まった理由を通知する**: 自動PR/自動マージは CI 失敗時にスキップ理由を通知し、main CI 失敗時は「デプロイ未実行」の理由を通知する

### デプロイ先

| 項目 | 値 |
|------|-----|
| サーバー | さくらVPS |
| IP | 133.167.124.112 |
| アプリパス | `/home/ubuntu/myapp` |
| Ruby | 3.3.7（rbenv） |

### 502エラー時のデバッグ

```bash
cd ~/myapp && RAILS_ENV=production rails runner "puts 'OK'" 2>&1 | head -5
```

- エラー → Railsシンタックスエラー等（コードを確認）
- "OK" → Puma/Nginx設定問題

## GitHub Actions ワークフロー修正時のルール

- `uses: actions/checkout` は必ず **`@v4`** を使う（v6は存在しない）
- ジョブには `permissions: contents: read` を最小権限で明示する
- Slack通知の JSON ペイロードは必ず **`jq`** で生成する（コミットメッセージの特殊文字でJSONが壊れるため）
- ロールバック用の一時ファイルは `/tmp/pre_deploy_sha_<run_id>` のように run_id で一意にする
- `auto_merge.yml` の保護対象では `.github/workflows/` 全体を一律除外しない。運用系（`auto_merge.yml` / `deploy.yml` / `auto_create_pr.yml` / `create_pr.yml` / `post_deploy_cleanup.yml`）は自動マージ対象に含める
- `ActiveJob::UnknownJobClassError` 再発防止のため、定期実行ジョブを追加・改名したら `config/initializers/required_job_classes.rb` と `lib/tasks/solid_queue.rake` の `REQUIRED_JOB_CLASSES` に同時反映する
- `ActiveJob::UnknownJobClassError` がデプロイ後に繰り返す場合、SolidQueueのforkモードが原因。`config/puma.rb` で `solid_queue_mode :async` を設定する。deploy.ymlのcleanup tasksはPuma再起動後に実行する。ブート時の自動cleanup は `config/initializers/solid_queue_boot_cleanup.rb` が担当する

## Slack 通知

- 通知ルーティングの正本は `docs/slack-notification-routing.md` を参照する
- カテゴリは以下の3つを使い分ける
  - ① CI/Deploy進捗（CI失敗含む）: `SLACK_WEBHOOK_URL_CI`
  - ② エラー（デプロイ失敗・アプリ障害等）: `SLACK_WEBHOOK_URL_ERROR`
  - ③ ジョブ/アクション結果: `SLACK_WEBHOOK_URL_JOBS`
- Rails `SlackNotifierService` は `channel: :jobs` を error にフォールバックさせない（誤配送防止）
- JSON は必ず `jq -n --arg key value '...'` で生成する（インジェクション・改行対策）

## DB操作ガイド（テスト環境）

Copilot coding agent のセッション中は **`RAILS_ENV=test bin/rails ...`** でテストDBに対してDB操作が可能。
テストDBは `copilot-setup-steps.yml` でセットアップ済み（`db:test:prepare` + 本番スナップショットのロード）。

### 構造確認

```bash
# 全テーブルのカラム定義・件数を一覧表示
RAILS_ENV=test bin/rails db:structure

# 任意のテーブルのカラム情報
RAILS_ENV=test bin/rails runner "AiUser.columns.each { |c| puts \"#{c.name}: #{c.sql_type}\" }"
```

### データ確認

```bash
# 各テーブルの最新5件を JSON で出力（引数でN件指定可）
RAILS_ENV=test bin/rails db:sample_data
RAILS_ENV=test bin/rails "db:sample_data[10]"

# 任意SQL（SELECT推奨）を実行してJSON出力
RAILS_ENV=test bin/rails "db:query[SELECT * FROM ai_users LIMIT 3]"
RAILS_ENV=test bin/rails "db:query[SELECT count(*) FROM ai_posts]"

# ActiveRecord で絞り込み
RAILS_ENV=test bin/rails runner "puts AiUser.where(active: true).last(3).to_json"
```

### データ作成・検証

```bash
# テストデータを作成して構造を確認
RAILS_ENV=test bin/rails runner "u = AiUser.create!(name: 'test'); puts u.to_json"

# 本番スナップショットをテストDBに再ロード（db/snapshots/db_snapshot.json が必要）
RAILS_ENV=test bin/rails db:snapshot_load
```

### ポイント

- テストDBなので壊しても問題なし。実装前の構造確認・実装後のデータ検証に積極的に使う
- スナップショット（`db/snapshots/db_snapshot.json`）があれば本番に近いデータで動作確認できる
- `db:structure` / `db:sample_data` / `db:query` は `lib/tasks/db_console.rake` で定義

## ローカル開発

```bash
docker compose up
```

- Rails: http://localhost:3000
- DB: PostgreSQL 16（`postgres:password@localhost:5432`）
- Redis: localhost:6379

## DBスナップショット（本番DB情報のJSON同期）

本番DBのデータをJSON形式でエクスポートし、`db-snapshots` ブランチに保存する仕組みがあります。

### 構成

| ファイル | 役割 |
|---|---|
| `lib/tasks/db_snapshot.rake` | `bin/rails db:snapshot` タスク（JSONをstdoutへ出力） |
| `.github/workflows/db_snapshot.yml` | VPS上でタスクを実行し `db-snapshots` ブランチへコミット |

### 実行方法

- **管理画面**: Admin Dashboard ナビの「DBスナップショット取得」ボタン
  - `DEPLOY_TOKEN` 環境変数（GitHub PAT / workflow権限）が必要
- **GitHub Actions UI**: Actions → "DB Snapshot for Claude" → Run workflow

### スナップショットの内容

- 全テーブルのレコード件数
- センシティブカラムを除いた各モデルの直近データ（users, ai_users, ai_profiles, ai_posts 等）
- 除外カラム: `encrypted_password`, `reset_password_token`, `stripe_customer_id`, `stripe_subscription_id`

### 注意

- 出力先ブランチは `db-snapshots`（orphanブランチ）
- ファイル名は `db_snapshot.json`（毎回上書き）
- 実行のたびに `snapshot: YYYY-MM-DD HH:MM UTC` でコミットされる

## PR作成時のチェックリスト

1. `bin/rubocop` でエラーがないことを確認
2. `bundle exec rspec` でテストが通ることを確認
3. CI失敗を修正した場合は `CLAUDE.md` の「CIエラーの原因になったこと」に追記する

## PR作成基準

### PR作成前の確認手順（必須）

**この順序でチェックしてから PR を作成する:**

1. **変更の性質を確認する**
   - ドキュメント・コメントのみの変更か、アプリ挙動に影響するか判断する
2. **ローカル検証を完了する**
   - `bin/rubocop` でLintエラーがないことを確認
   - `bundle exec rspec` でテストが通ることを確認
   - フロント変更がある場合はフロント側テストも実行
3. **以下の条件を全て満たしたら PR を作成する**
   - 変更目的が明確である
   - 失敗テストがない
   - セキュリティ・機密情報が混入していない
   - 差分がレビュー可能なサイズである

### PR作成の判断ルール

| 変更の種類 | PR作成のタイミング |
|---|---|
| 軽微変更（文言・コメントのみ） | まとめて1つのPR可 |
| 挙動変更あり | 毎回PR作成 |
| CI不安要素あり | 手動確認完了後にPR作成 |

## セッション継続モード（会話中の自動マージ停止）

### 基本仕様

- **CI通過→自動マージ→自動デプロイ** が基本動作（デフォルト）
- 対話セッション中のブランチのみ `session-hold` ラベルで一時停止する

### セッションモードの判定

セッション開始時に、ユーザーの指示からモードを判定してブランチ名を決める:

| ユーザーの指示例 | モード | ブランチ命名 |
|---|---|---|
| 「デプロイまで進めて」「自動でやって」「おまかせ」「そのままマージして」 | 自動完走 | `copilot/auto-{内容}` |
| 「相談したい」「確認しながら進めて」（または特に指定なし） | 対話hold | `copilot/{内容}` |

- **自動完走モード**: 作業完了後にユーザーの確認を待たず、CI通過で自動マージ・デプロイまで進む
- **対話holdモード（デフォルト）**: PRに `session-hold` ラベルが付き、ユーザーがラベルを外すまでマージされない
- 明示的に自動完走を指示されない限り、デフォルトは安全側（hold）にする
- 途中で気が変わった場合は、手動で `session-hold` ラベルを付け外しすれば対応可能

### session-hold の付与ルール

`create_pr.yml` でPR自動作成時に、ブランチ名で判定:

| ブランチパターン | session-hold | 理由 |
|---|---|---|
| `copilot/auto-*` | **付けない** | ユーザーが自動完走を指示。CI通過で即マージ |
| `copilot/ai-sns-*` | **付けない** | AI SNS自動進行。CI通過で即マージ |
| `auto-fix/*` | **付けない** | CI自動修正。CI通過で即マージ |
| `claude/*`, `copilot/*`（上記以外） | **付ける** | 対話セッション中。会話完了後にラベルを外す |

### 仕組み

```
push → create_pr.yml でPR作成
    ↓
[自動進行ブランチ]                     [対話セッションブランチ]
session-hold なし                      session-hold ラベルを自動付与
    ↓                                      ↓
CI 通過 → 即マージ → デプロイ          CI 通過 → session-hold を検出 → マージをスキップ
                                           ↓
                                       会話完了後: session-hold ラベルを外す
                                           ↓
                                       auto_merge.yml の unlabeled トリガー発火 → 即マージ → デプロイ
```

### 操作手順（対話セッションの場合）

1. **会話中**: Copilot/Claude が作業しながら `report_progress` でコミットを積む。PRが自動作成され `session-hold` ラベルが付く。CIが通ってもマージされない。
2. **会話完了**: GitHubのPRページを開き、`session-hold` ラベルの `×` をクリックして外す。
3. **自動マージ**: ラベル除去を検知した `auto_merge.yml` がCI通過を確認し、即座にマージ＆デプロイを起動。

### 注意

- `session-hold` ラベルは会話完了後に必ず外す（外さないとデプロイされない）
- CI未通過のままラベルを外した場合、次のCI成功時に自動マージされる
- 手動でマージしたい場合はラベルを外さずにGitHub UIから直接マージ可能（その場合デプロイは手動 dispatch が必要）
- 自動進行ブランチ（`copilot/auto-*`, `copilot/ai-sns-*`, `auto-fix/*`）は `session-hold` が付かないため、CI通過で自動マージされる

## データ migration ガイド（現行 Rails migration 方式の強化ルール）

自動 PR デプロイフローのデータ操作は **Rails migration** で管理する（追加ツール不要）。
`bin/rails db:migrate` はデプロイフローに組み込み済みで、PR マージ → デプロイ → migration 自動実行が保証される。

### 4 つの必須ルール

1. **冪等に書く**（何度実行しても結果が同じになるよう guard を入れる）
   - `find_or_create_by!` / `upsert` / `update_columns WHERE xxx IS NULL` を使う
   - `Ledgers::AiSnsPlanSync.create_plan_item!` は内部で upsert しているので idempotent
   - `create_table` は `if_not_exists: true`、`add_index` は `if_not_exists: true` を付ける

2. **`down` を必ず書く**
   - ロールバック可能な場合は逆操作を書く
   - 本当に不可逆な場合は `raise ActiveRecord::IrreversibleMigration`（`NotImplementedError` のまま放置しない）

3. **`db/schema.rb` の `version` を必ず更新する**
   - DDL 変更なしのデータ操作 migration でも `schema.rb` の version は最新番号に更新される
   - version を更新せずコミットすると CI で `ActiveRecord::PendingMigrationError` が発生する

4. **モデルに強く依存する操作は `update_columns` / `execute(SQL直書き)` を使う**
   - migration 実行時点でモデル定義が変わっていても壊れないようにする
   - `before_validation` / `after_save` などのコールバックを bypass できる `update_columns` が安全

### 命名規則（ファイル名プレフィックスで種別を明示）

| プレフィックス | 用途 | 例 |
|---|---|---|
| `backfill_` | 既存レコードの NULL 埋め・カラム補完 | `backfill_missing_source_meeting_ids` |
| `seed_` | マスタデータ・初期値の投入 | `seed_organization_roles` |
| `mark_` | ステータス・フラグの一括更新 | `mark_d1_life_story_completed` |
| `disable_` / `enable_` | スケジュール・フラグの有効/無効切替 | `disable_ui_check_ledger_run_schedule` |
| `add_xxx_plan_items` | AI SNS 計画項目の追加 | `add_ai_sns_plan_items_phase2` |
| 通常の migration | DDL 変更（スキーマ変更）を伴う場合 | `add_column_to_ticket_ledgers` |

### ツール

- **専用ジェネレーター**: `bin/rails generate data_migration <名前>` で冪等テンプレートつき migration を生成
  - 例: `bin/rails generate data_migration mark_a1_as_completed`
  - 生成元: `lib/generators/data_migration/`
- **健全性チェック**: `bin/rails db:migrate:lint` で `down` 未実装の data migration を検出
  - 定義元: `lib/tasks/db_migrate.rake`

### ユースケース別の実装パターン

```ruby
# ■ AI SNS 計画アイテム追加（自動 PR デプロイ標準パターン）
def up
  Ledgers::AiSnsPlanSync.create_plan_item!(item_key: "X1", title: "...", priority: :high, ...)
end
def down
  ikey = Ledgers::AiSnsPlanSync.idempotency_key_for("X1")
  TicketLedger.find_by(idempotency_key: ikey)&.destroy
end

# ■ チケットステータス更新（mark_xxx.rb パターン）
def up
  ticket = TicketLedger.find_by(idempotency_key: "ai_sns_plan:X1")
  return unless ticket
  return if ticket.status_completed?  # 冪等ガード
  ticket.update_columns(status: TicketLedger.statuses[:completed], resolved_at: Time.current)
end
def down
  raise ActiveRecord::IrreversibleMigration
end

# ■ スケジュール無効化（disable_xxx.rb パターン）
def up
  ServiceScheduleDefinition.where(job_key: "xxx").update_all(enabled: false) if table_exists?(:service_schedule_definitions)
end
def down
  ServiceScheduleDefinition.where(job_key: "xxx").update_all(enabled: true) if table_exists?(:service_schedule_definitions)
end

# ■ 大量 backfill（backfill_xxx.rb パターン）
def up
  Model.where(column: nil).find_each do |record|
    record.update_columns(column: compute_value(record))
  end
end
def down
  raise ActiveRecord::IrreversibleMigration
end
```
