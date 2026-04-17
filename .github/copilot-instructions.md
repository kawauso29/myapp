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
| GitHub Actions 自前移行（self-hosted runner） | `docs/projects/github-actions-migration.md` | ✅ 完了（ci.yml テスト7ジョブ/copilot-setup-steps.yml/build_frontend以外は全て移行済み） |
| 運営 OS Phase 30〜41 実装 | `docs/projects/operating-spec-phase-30-plan.md` | 🔧 進行中（Phase 30a: idempotency_key / carry_over_items 投入済み。30b/31 以降は別 PR） |

## コーディングルール（Ruby / Rails）

### やってはいけないこと（CIで必ず引っかかる）

- `Time.now` は使わない → **`Time.current`** を使う（Rails/TimeZone cop）
- `"str" + method()` の文字列結合は使わない → **`"str#{method()}"`** 補間を使う
- `head :unauthorized and return` は使わない → **`return head :unauthorized`** を使う
- private ブロック内に定数を定義しない → **private より前に定義する**
- `actions/checkout@v6` は存在しない → **`@v4`** を使う
- `enum :status, { pending: 0 }, prefix: true` のようにprefixつきenumのスコープ名は **`status_pending`**（`pending` ではない）。specでmockする場合も `receive_message_chain(:status_pending, :count)` のようにprefixつきで書く
- `weekly_pdca.yml` の `WIP_COUNT=$(grep -c ... || echo 0)` は `0\n0` になり GITHUB_OUTPUT 書き込みが `Invalid format '0'` で落ちる → `|| true` + `${WIP_COUNT:-0}` に修正する
- self-hosted runner（sakura-vps）には `jq` が入っていない → self-hosted で動くワークフロー内では `jq` の代わりに `python3 -c "import json, os ..."` で JSON 生成・パースする
- ワークフローで Copilot coding agent にメンションする場合は `@github-copilot` ではなく **`@copilot`** を使う（`@github-copilot` では反応しない）
- `GITHUB_TOKEN` で作成したコメント/Issueは Copilot coding agent の Webhook をトリガーしない（GitHub のループ防止仕様）。`@copilot` メンションを含むコメントは必ず `github-token: ${{ secrets.DEPLOY_TOKEN }}` で投稿する。`DEPLOY_TOKEN` は **fine-grained PAT で `Issues: Read and Write` スコープが必須**。スコープ不足で 403 が出る場合は GitHub Settings → Developer settings → Personal access tokens → DEPLOY_TOKEN を `Issues: Read and Write` で再発行する
- `ai_sns_plan.yml` で `git commit --allow-empty` を使うと空PRが作成され、auto_mergeがCopilot実装前にマージしてしまう → ①`auto_merge.yml` に空PRガード（変更ファイル数チェック）を追加、②PRは `draft: true` で作成、③`--allow-empty` の代わりに実ファイル変更をコミットする
- `ai_sns_plan.yml` で `@copilot` をPR本文（body）に書いても Copilot coding agent は起動しない → PR作成後に `issues.createComment` で別途PRコメントとして `@copilot` メンションを投稿する
- `plan_review.yml` でも同様に `@copilot` をIssue本文（body）に書いても起動しない → Issue作成後に `issues.createComment` で別途Issueコメントとして `@copilot` メンションを投稿する（DEPLOY_TOKEN使用）
- `plan_review.yml` の open Issue 重複チェックは7日超の古い Issue を自動クローズしてから新規作成する（Copilot 無反応による永久ブロック防止）
- `weekly_pdca.yml` は `in_progress` 項目の `started_at` が7日以上前なら自動で `todo` にリセットする（WIP 上限永久到達の防止）
- `auto_merge.yml` は計画追加PRマージ後に `plan-review` ラベル付き open Issue を自動クローズする（計画レビューサイクルの循環維持）
- Puma 8.x は `config/puma/{environment}.rb` が存在すると `config/puma.rb` を**読み込まない** → `config/puma/production.rb` に SolidQueue プラグイン設定（`plugin :solid_queue`, `solid_queue_mode :async`）と `.env` ロードを必ず含める
- `config/puma/production.rb` で `workers N`（N>0）を設定するとクラスターモード（fork）になり、SolidQueue async スレッドでジョブクラス解決が失敗する → 単一VPSでは `workers` と `preload_app!` を使わずシングルプロセスモードにする
- デプロイ中の Puma 再起動時に SolidQueue recurring task が `ActiveJob::UnknownJobClassError` で一時的に失敗する → `config/initializers/active_job_unknown_class_retry.rb` で `ActiveJob::Base.deserialize` を prepend し、失敗時に `eager_load!` → リトライする。管理画面 Failed Jobs でクラスがロード可能な一時的失敗は自動 discard する
- `deploy.yml` の `workflow_run` トリガーが self-hosted runner 移行後に発火しなくなった → `ci.yml` に `dispatch_deploy` ジョブを追加し、main の CI 成功後に `deploy.yml` を `workflow_dispatch` で直接起動する（auto_merge.yml と同じ方式）。`deploy.yml` からは `workflow_run` トリガーを廃止済み。`dispatch_deploy` にはリトライロジック（最大3回）を追加済み
- `bin/check_runner_health` の systemd サービス名が実際と不一致 → `./svc.sh install` で作成されるサービス名はホスト名ベース（`actions.runner.kawauso29-myapp.os3-392-29108.service`）。ラベル名（`sakura-vps`）やユーザー名（`ubuntu`）ではない

### メソッド・スタイル

- `redirect_back` の引数はカッコなし: `redirect_back fallback_location: path, notice: "..."` （Ruby 3.3でカッコ＋カンマはSyntaxError）
- Rails の規約に従い、controller は `before_action` でフィルタを定義する

## デプロイ・CI のルール

### ブランチ戦略

1. 作業は必ずフィーチャーブランチ（`claude/...` または `copilot/...`）で行う
2. 作業前に `git branch -a` で重複ブランチがないか確認する
3. CI（scan_ruby / scan_js / lint / test / system-test）が全て通ってからマージする
4. マージ後はブランチを削除する（ローカル・リモート両方）

### CI/CD の仕組み

```
main への直接 push
    ↓
[CI ワークフロー] scan_ruby / scan_js / lint / test / system-test
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
  - ① CI/Deploy進捗: `SLACK_WEBHOOK_URL_CI`
  - ② エラー: `SLACK_WEBHOOK_URL_ERROR`
  - ③ ジョブ/アクション結果: `SLACK_WEBHOOK_URL_JOBS`
- Rails `SlackNotifierService` は `channel: :jobs` を error にフォールバックさせない（誤配送防止）
- JSON は必ず `jq -n --arg key value '...'` で生成する（インジェクション・改行対策）

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
