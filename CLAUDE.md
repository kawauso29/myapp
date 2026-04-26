# CLAUDE.md

Claude Code向けのプロジェクトメモ。

## 進行中プロジェクト

AI エージェント間の認識統一のため、進行中のプロジェクトを以下で管理する。
作業前に必ず該当ドキュメントの「現状」と「TODO」を確認すること。

| プロジェクト | ドキュメント | 状態 |
|---|---|---|
| GitHub Actions 自前移行（self-hosted runner） | `docs/projects/github-actions-migration.md` | ✅ 完了（build_frontend以外は全て移行済み。copilot-setup-steps.yml/pr_guardrails.yml も self-hosted 化完了） |
| 運営 OS Phase 30〜41 実装 | `docs/projects/operating-spec-phase-30-plan.md` | ✅ 完了（Phase 30〜44 完了。Phase 44 で DB化・heartbeat駆動・組織ロールマスタ・enforce ON を実装済み） |

## Claude Codeへの指示

### コマンドの提示方法

**ユーザーはスマホからSSHでコマンドを実行することが多い。スマホでのコピペはマルチライン（複数行）が崩れやすい。**

- コマンドを提示するときは**1行のワンライナーを優先**する
- 複数のコマンドをまとめる場合は `&&` でつなぐ
- どうしても複数行になる場合は**シェルスクリプトファイルに書き出して `bash script.sh` で実行する形**を提案する
- コードブロック内のインデントや改行が崩れると実行できないため、シンプルな構造を心がける

### メモの更新ルール

- **重要な情報が出てきたら必ずこの CLAUDE.md に追記する**
- **間違いを指摘されたら、その内容と正しい情報を CLAUDE.md に記録する**
- **`.github/copilot-instructions.md` と CLAUDE.md は連動管理し、ルール更新時は必ず両方を更新する**

### mainへのマージの強制ルール

**作業完了後は必ずmainにマージ・pushする。**

- フィーチャーブランチで作業したら、必ず `git checkout main && git merge <branch> && git push origin main` を実行する
- ユーザーが「mainにあげておいて」と言った場合は、マージとpushまで自動で行う
- ローカルmainがorigin/mainと乖離している場合は `git fetch origin main && git reset --hard origin/main` で同期してからマージする

## デプロイ仕様

### 自動デプロイのトリガー

**`main` ブランチに push すると自動デプロイが走る。**

- ワークフロー: `.github/workflows/deploy.yml`
- GitHub Actions が起動し、さくらVPSにSSH接続してデプロイを実行する

### デプロイ先

| 項目 | 値 |
|------|-----|
| サーバー | さくらVPS |
| OS | Ubuntu 22.04.4 LTS |
| IP | 133.167.124.112 |
| ユーザー | ubuntu |
| アプリパス | `/home/ubuntu/myapp` |

### デプロイ手順（GitHub Actionsが自動実行）

```
git fetch origin main
git reset --hard origin/main
eval "$(rbenv init -)"
bundle install
RAILS_ENV=production bin/rails db:migrate
RAILS_ENV=production bin/rails runner "ActiveRecord::Tasks::DatabaseTasks.prepare_all"
RAILS_ENV=production bin/rails assets:precompile
rm -rf tmp/cache/*
sudo systemctl restart puma
sleep 5
RAILS_ENV=production bin/rails runner "Rails.application.eager_load!"
```

### サーバー構成

- **Webサーバー**: Nginx → Puma（Unixソケット経由）
  - ソケット: `/home/ubuntu/myapp/tmp/sockets/puma.sock`
  - Puma は systemd で管理（`sudo systemctl restart puma`）
  - sudoers でパスワードなし再起動を許可済み
- **DB**: PostgreSQL（ユーザー: ubuntu、DB: myapp_production）
- **Ruby**: 3.3.7（rbenv: `~/.rbenv`）
- **Rails**: 8.1.2

### GitHub Secrets（Actions用）

| Secret名 | 内容 |
|----------|------|
| `VPS_HOST` | 133.167.124.112 |
| `VPS_USER` | ubuntu |
| `VPS_SSH_KEY` | GitHub Actions専用 ed25519 秘密鍵 |

### 502エラー時のデバッグ手順

502が出たらRailsの起動エラーを確認する（VPS上で実行）:

```bash
cd ~/myapp && RAILS_ENV=production rails runner "puts 'OK'" 2>&1 | head -5
```

- エラーが出る → Railsが起動できていない（コードのSyntaxエラー等）
- "OK" と表示される → PumaやNginxの設定問題

Pumaの再起動: `sudo systemctl restart puma`

### 過去の障害記録

#### 2026-04-05: 502エラー（Railsシンタックスエラー）

- **原因**: `admin/ai_sns_controller.rb` の `redirect_back` の書き方が間違っていた
- **誤り**: `redirect_back(fallback_location: path), notice: "..."` （noticeがカッコの外）
- **正しい**: `redirect_back fallback_location: path, notice: "..."` （noticeをカッコなしで同じ引数に）
- Ruby 3.3 では `method(args), key: val` はシンタックスエラーになる

#### 2026-04-10: ActiveJob::UnknownJobClassError（複数ジョブクラス）

- **原因**: Bootsnapのキャッシュが古く、ジョブクラスがオートロードされない
- **エラー**: RelationshipDecayJob, SlackForwardToClaudeJob, MonitorFailedJobsJob など複数のジョブで発生
- **誤った解決策（2026-04-10）**: 各ステップ後に複数回キャッシュクリア → Puma再起動後のキャッシュクリアは無意味
- **正しい解決策（2026-04-11）**:
  - Puma再起動**直前**に1回だけ `rm -rf tmp/cache/*` を実行
  - Puma再起動後、`RAILS_ENV=production bin/rails runner "Rails.application.eager_load!"` で全クラスをロード
  - これにより、Pumaが起動時に正しいキャッシュを生成・使用できる
- **重要**: 中間でのキャッシュクリアは不要。Puma再起動直前のクリアと、再起動後のeager_loadが重要
- **2026-04-11追記**: solid_queueは `SOLID_QUEUE_IN_PUMA=1` でPuma内部で動作しているため、systemdのsolid_queueサービスは存在しない。Pumaの再起動だけでsolid_queueも再起動される。sleep時間を10秒に延長してPumaの完全起動を待つ。
- **2026-04-12追記**: `ActiveJob::UnknownJobClassError` が特定ジョブ（例: `PostGenerateJob`）で継続する場合、デプロイ時に `bin/rails solid_queue:cleanup_unknown_job_classes` を実行して、存在しない `job_class` を参照する未完了 ActiveJob ラッパージョブを削除する。あわせてデプロイ時の `required` ジョブ定数チェックに対象ジョブを追加して検知する。

## Slack自動転送システム（SlackEventsController）

### 概要

エラー通知チャネルのメッセージを検知し、GitHub Copilot Slack アプリに DM で自動転送する。

- エンドポイント: `POST /slack/events`
- 転送ジョブ: `SlackForwardToClaudeJob`

### 必要なGitHub Secrets（デプロイ時にVPSの.envに自動書き込み）

| Secret名 | 内容 |
|----------|------|
| `SLACK_SIGNING_SECRET` | Slack App → Basic Information → Signing Secret |
| `SLACK_BOT_TOKEN` | Slack App → OAuth & Permissions → Bot User OAuth Token（xoxb-...）|
| `SLACK_ERROR_CHANNEL_ID` | 監視対象チャネルのID（Cxxxxx）|
| `SLACK_GITHUB_MEMBER_ID` | GitHub Copilot Slack AppのメンバーID（転送先DM相手。Slack APIの `users.list` 等で取得）|

### Slack App設定

- Bot Token Scopes: `channels:history`, `chat:write`
- Event Subscriptions → Request URL: `https://133.167.124.112/slack/events`
- Subscribe to bot events: `message.channels`
- BotをエラーチャネルとGitHub Copilotチャネル両方に `/invite` すること

### 重要な注意点・ハマりポイント

**エラー通知はBotメッセージ**
- `myapp-notify` はIncoming Webhook経由のBotとして投稿する
- `bot_id` チェックで除外するとエラー通知が転送されない（ハマった）
- **正しい実装**: `bot_id` チェックは行わず、キーワードフィルタで判定する
- `subtype` の一括チェックも NG。`bot_message` サブタイプも弾いてしまう
- 除外すべき subtype は `message_changed`, `message_deleted`, `channel_join`, `channel_leave` のみ明示的に指定する

**GitHub Copilot への転送方式**
- `SLACK_GITHUB_MEMBER_ID`（GitHub Copilot Slack AppのメンバーID）をチャネルとして `chat.postMessage` に渡すことでDM転送
- `@GitHub` メンションのテキスト挿入は不要（DM先がGitHubアプリ本体のため）
- 旧方式（`SLACK_CLAUDE_CHANNEL_ID`）はClaudeチャネルへの転送で、2026-04-12に廃止

**ループ防止**
- 転送先は GitHub Copilot app DM（`SLACK_GITHUB_MEMBER_ID`）のみに投稿
- エラーチャネル（`SLACK_ERROR_CHANNEL_ID`）には絶対に書き込まない

### ローカル開発環境（Docker）

```bash
docker compose up
```

- Rails: http://localhost:3000
- DB: PostgreSQL 16（`postgres:password@localhost:5432`）
- Redis: localhost:6379
- 設定: `docker-compose.yml` + `Dockerfile.dev`

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

## Slack通知 3カテゴリ設計

通知ルーティングの正本は `docs/slack-notification-routing.md`。

### カテゴリ定義と送信先

| カテゴリ | 内容 | GitHub Secret | VPS .env |
|---|---|---|---|
| ① CI/Deploy進捗 | CI成功/失敗, デプロイ開始/成功, PR通知 | `SLACK_WEBHOOK_URL_CI` | 不要（GitHub Actionsのみ） |
| ② エラー | デプロイ失敗, アプリ障害, レート制限 | `SLACK_WEBHOOK_URL_ERROR` | `SLACK_WEBHOOK_URL_ERROR` |
| ③ ジョブ/アクション結果 | auto-fix PR作成, auto-merge結果, triage issue通知, AI投稿運用ログ | `SLACK_WEBHOOK_URL_JOBS` | `SLACK_WEBHOOK_URL_JOBS` |

### フォールバック仕様

GitHub Actions側は未設定時に既存の `SLACK_WEBHOOK_URL` へフォールバック可能な実装を維持する（後方互換）。
ただし Rails の `SlackNotifierService` は誤配送防止のため `channel: :jobs` を error チャネルへはフォールバックしない。

### ワークフロー別マッピング

| ワークフロー | 通知 | カテゴリ |
|---|---|---|
| `ci.yml` notify success | CI passed | ① |
| `ci.yml` notify failure | CI failed | ① |
| `deploy.yml` start/success | デプロイ開始/成功 | ① |
| `deploy.yml` failure | デプロイ失敗 | ② |
| `auto_fix.yml` | auto-fix PR作成/lint失敗 | ③ |
| `auto_fix.yml` triage_ci_failures | test/check系CI失敗Issue | ③ |
| `pr_ci_fix.yml` | PR CI自動修正結果 | ③ |
| `post_deploy_cleanup.yml` create_deploy_failure_issue | デプロイ失敗Issue起票 | ② |
| `auto_merge.yml` | auto-merge失敗 | ③ |
| `auto_merge.yml` | 計画項目完了（done自動更新） | ① |
| `plan_review.yml` | 計画レビュー自動起票 | ① |

### アプリ側（SlackNotifierService）

`SlackNotifierService` は `channel: :error`（カテゴリ②）と `channel: :jobs`（カテゴリ③）を使い分ける。
`deploy.yml` の env sync ステップで `SLACK_WEBHOOK_URL_ERROR` / `SLACK_WEBHOOK_URL_JOBS` をVPSへ同期する。
`channel: :jobs` は未設定時に error へフォールバックせず通知をスキップする。

### Slackからの自動修正ルートについて

Slack→Copilot自動修正（`SlackEventsController` → `SlackForwardToClaudeJob`）は
**カテゴリ② のエラーメッセージ専用**に限定する。
CI進捗通知などはここに流さない（`forwardable_message?` のフィルタで制御）。
自動起動は補助機能扱いで、主経路はIssue/PRコメント起票とする。

## CI自動リカバリーシステム

### 仕組みの概要

```
main への push（直接 push）
    ↓
[CI ワークフロー] （scan_ruby / lint / job-check / route-check / test）
    ↓ 成功                        ↓ 失敗
[dispatch_deploy ジョブ]       [Auto Fix ワークフロー]
  → deploy.yml を dispatch       ↓ rubocop --autocorrect
    ↓                            ↓ 自動修正PRを作成 + Slack通知
[Deploy ワークフロー]
  ↓ ヘルスチェック（5回）
  ↓ 失敗 → ロールバック実行
  ↓ Slack通知（原因・次アクション付き）

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

### デプロイゲート（deploy.yml）

- `main` push だけでデプロイが走らない。**CI が全ジョブ成功した後にのみ** deploy.yml が起動する
- トリガー: `ci.yml` の `dispatch_deploy` ジョブが CI 全成功後に `deploy.yml` を `workflow_dispatch` で直接起動する
- `deploy.yml` には `workflow_dispatch` トリガーのみ（`workflow_run` は self-hosted runner 移行後に機能しなくなったため廃止済み）
- `workflow_dispatch` で手動デプロイは引き続き可能
- `auto_merge.yml` はマージ成功後に `deploy.yml` を `workflow_dispatch` で直接起動する（GITHUB_TOKEN によるマージでは push イベントが発火せず CI→deploy の連鎖が起きないため）
- 自動PR/自動マージは CI 失敗時に「なぜスキップされたか」を Slack 通知する。main CI 失敗時は「自動デプロイ未実行」の理由も通知する。

### ヘルスチェック + ロールバック（deploy.yml）

- デプロイ後に `curl http://localhost/` で 3 回リトライしてヘルスチェック
- 失敗した場合、デプロイ前の SHA（`/tmp/pre_deploy_sha`）に自動ロールバック
- Slack 通知に「原因」「次のアクション」を含める

### RuboCop 自動修正（auto_fix.yml）

- CI が失敗したとき `rubocop --autocorrect` を自動実行
- 自動修正可能な違反があれば自動的に PR を作成し、Slack 通知
- 自動修正できない場合は「手動修正が必要」と Slack 通知
- PR テンプレートに「再発防止ルールを CLAUDE.md に追記したか」のチェックがある

### CI失敗後の標準フロー

1. Slack で失敗通知を受け取る
2. 自動修正PRが来ていれば内容確認してマージ
3. 手動修正が必要な場合はフィーチャーブランチで修正→PR作成
4. **必ずPRの「再発防止ルール」欄を埋めて CLAUDE.md に追記する**

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

## CI・デプロイのルール

### mainへのマージ・pushの手順

**必ずこの順序で実行する:**

1. 作業はフィーチャーブランチ（`claude/...`）で行う
2. **作業開始前に、他ブランチで同じ作業が進んでいないか必ず確認する（`git branch -a` で確認）**
3. mainにマージ・pushする前にCIが通ることを確認する
4. マージ方法: `git checkout main && git merge <branch> && git push origin main`
5. mainへのpushで自動デプロイが走る
6. **マージ後は必ずブランチを削除する: `git branch -d <branch> && git push origin --delete <branch>`**

### Slackからの自動修正時のルール

- **作業開始前に必ず他ブランチで同じ修正が進んでいないか確認する**
  - `git branch -a` でリモートブランチも含めて確認
  - 同名・類似の修正ブランチがあれば重複作業を避ける
- **マージ完了後は必ずフィーチャーブランチを削除する（ローカル・リモート両方）**

### CIエラーの原因になったこと（記録）

- `actions/checkout@v6` は存在しない → `@v4` を使う
- `head :unauthorized and return` は RuboCop違反 → `return head :unauthorized` を使う
- privateブロック内に定数を定義するとRuboCop警告 → privateより前に定義する
- `"str" + method()` の文字列結合 → `"str#{method()}"` 補間を使う
- `Time.now` はRails/TimeZone違反 → `Time.current` を使う
- `Redis.current` は Redis 5.x で廃止 → `$redis`（`config/initializers/redis.rb` で定義）を使う
- テスト環境で `Rack::Attack` のレート制限がリクエストspecに干渉する → `config/initializers/rack_attack.rb` で `Rails.env.test?` の場合は `Rack::Attack.enabled = false` にする
- jobのspec: `AiUser.find(id)` はDBから新規インスタンスを返すため、インスタンスレベルのstubが効かない → `allow(AiUser).to receive(:find).with(id).and_return(instance)` でstubする
- jobのspec: `AiUser.where.find_each` で取得した別AIがdaily_stateを持たないとprocess_aiが早期returnしてしまいselectが期待回数呼ばれない → テスト対象の全AIにdaily_stateを作成する
- CIのSlack通知JSONを文字列直書きするとコミットメッセージの記号/改行で通知ジョブが落ちる → `jq -n --arg ...` で常にJSONを生成する
- `auto_fix.yml` をCI失敗全体で起動するとlint無関係の失敗でも自動修正フローが走り運用ノイズになる → workflow_runのjob一覧から `lint` 失敗時だけ実行する
- `auto_merge.yml` の保護パターンで `.github/workflows/` 全体を対象にすると、PR自動作成/自動マージ/自動デプロイ改善のワークフロー修正PRまで自動マージされず詰まる → 運用系（`auto_merge.yml` / `deploy.yml` / `auto_create_pr.yml` / `create_pr.yml` / `post_deploy_cleanup.yml`）は保護対象から除外する
- 本番で `MonitorFailedJobsJob` のSlack通知が来ない場合、VPS `.env` に `SLACK_WEBHOOK_URL_ERROR` が同期されているか確認する（旧 `SLACK_WEBHOOK_URL`。`deploy.yml` が自動同期するが未設定の場合は手動で `SLACK_WEBHOOK_URL_ERROR=<webhook>` を追記）
- `ActiveJob::UnknownJobClassError` が継続する場合、**誤り**: systemdのsolid_queueサービスを再起動 → **正しい**: solid_queueは `SOLID_QUEUE_IN_PUMA=1` でPuma内で動作しているため別途再起動不要。Pumaの再起動後に十分な待機時間（10秒）を確保し、その後 `eager_load!` を実行する
- `ActiveJob::UnknownJobClassError` 再発防止のため、定期実行ジョブを追加・改名したら `config/initializers/required_job_classes.rb` と `lib/tasks/solid_queue.rake` の `REQUIRED_JOB_CLASSES` に同時反映する
- `ActiveJob::UnknownJobClassError` 再発時、legacyジョブ停止のPID抽出が `$2/$3 == bin/jobs` だけだと `bundle exec bin/jobs` を取りこぼす。`ps -eo pid,args | awk` でコマンド全体を正規表現マッチして停止対象を拾う
- `ActiveJob::UnknownJobClassError` がデプロイ後に繰り返し発生する場合、SolidQueueのPumaプラグインがデフォルトでforkモード（別プロセス）で動作しており、forked processでクラス解決に失敗することが原因。**正しい対処**: `config/puma.rb` で `solid_queue_mode :async` を設定し、SolidQueueをPumaと同一プロセス内のスレッドで動作させる。deploy.ymlのcleanup tasksはPuma再起動**後**に実行する（再起動前のcleanupは古いSolidQueueがまだ動作中で新たなfailureを生成するため無意味）。さらに `config/initializers/solid_queue_boot_cleanup.rb` でブート時に自動的にstale UnknownJobClassError failuresをdiscardする
- `deploy.yml` の `stop_puma_for_code_switch` 関数は `sudo systemctl stop puma` が sudoers に未登録で失敗するが、 `|| return 0` で成功扱いになりPumaは実際には停止しない。`restart` のみ sudoers 許可済みなので、stop/is-active は使わず `restart` のみに依存する
- legacy `bin/jobs` 停止処理で `ps ... args` の全文一致だけを使うと、`ssh-action` 実行中の `bash -c`（スクリプト本文に `bin/jobs` を含む）まで誤検知して自己終了(143)することがある → `ps -eo pid,comm,args` で `bash/sh` を除外し、さらに `$$` と `$PPID` を kill 対象から除外する
- PRを**手動マージ**（GitHub UI経由）するとデプロイが自動起動しない。`auto_merge.yml` の deploy dispatch は「auto_merge自身がPRをマージした直後」のみ発火する。手動マージ後にデプロイが必要な場合は、GitHub Actions UI から `deploy.yml` を手動 `workflow_dispatch` するか、Copilot に「デプロイだけ進めといて」と依頼して小さなPRを作成してもらう。
- `auto_merge.yml` で GITHUB_TOKEN を使って PR をマージすると、main への push イベントが発火しない（GitHub の仕様でループ防止）→ CI が main で走らず deploy も起動しない → **正しい対処**: マージ成功後に `github.rest.actions.createWorkflowDispatch` で `deploy.yml` を直接起動する（`workflow_dispatch` は GITHUB_TOKEN の制限の例外）
- `enum :status, { pending: 0, ... }, prefix: true` のようにprefixオプションを付けたenumのスコープ名は `model.pending` ではなく `model.status_pending` になる。specでモックする場合も `receive_message_chain(:status_pending, :count)` のようにprefixつきスコープ名を使う（`prefix: true` を見落としてスコープ名を誤るとCI失敗の原因になる）
- `line-bot-api` 2.7 には `Line::Bot::Client` が存在しない。`LineNotifierService` は `Line::Bot::V2::MessagingApi::ApiClient` + `*_with_http_info` で実装する。job spec で送信呼び出し回数を検証するときは `expect_any_instance_of(...).to have_received(...)` は使えないため、`LineNotifierService.new` を明示的にstubしたdoubleで `have_received` を使う
- `Ledgers::ImprovementDetector` のspecで個別ルールの検知件数を1件に固定して検証する場合、`stale_ui_check` ルールの副作用を避けるため `ui_check` の直近開催データを先に作成する（未作成だと `result[:detected]` が +1 される）
- `weekly_pdca.yml` の `WIP_COUNT=$(grep -c ... || echo 0)` は `0\n0` になり GITHUB_OUTPUT 書き込みが `Invalid format '0'` で落ちる → `|| true` + `${WIP_COUNT:-0}` に修正する
- self-hosted runner の CI で `db:test:prepare` だけを実行すると、新規 migration 追加直後に `ActiveRecord::PendingMigrationError` で `job-check` / `route-check` / `test` が同時に落ちることがある → `ci.yml` の各ジョブで `bin/rails db:migrate || bin/rails db:schema:load` の後に `bin/rails db:test:prepare` を実行する。`db:migrate` が `PG::DuplicateTable` 等で失敗した場合は `db:schema:load` にフォールバックしてテストDBを schema.rb から再構築する
- self-hosted runner の CI で PostgreSQL のテストDB（`myapp_test` / `myapp_test_queue`）が未作成だと `db:test:prepare` が `ActiveRecord::NoDatabaseError` で失敗する → `ci.yml` の `job-check` / `route-check` / `test` の先頭で `bin/rails db:create` を実行してから `db:migrate || db:schema:load` と `db:test:prepare` を実行する
- self-hosted runner（sakura-vps）には `jq` が入っていない → self-hosted で動くワークフロー内では `jq` の代わりに `python3 -c "import json, os ..."` で JSON 生成・パースする
- `pr_ci_fix.yml` / `auto_fix.yml` / `ai_sns_plan.yml` で Copilot に自動修正を依頼するメンションは `@github-copilot` ではなく **`@copilot`** を使う。`@github-copilot` では Copilot coding agent が反応しない
- `GITHUB_TOKEN` で作成したコメント/Issueは GitHub Apps（Copilot coding agent）の Webhook をトリガーしない（GitHub のループ防止仕様）。`@copilot` メンションを含むコメントは必ず `DEPLOY_TOKEN`（fine-grained PAT）で投稿する。**`DEPLOY_TOKEN` には `Issues: Read and Write` スコープが必須**。403 が出る場合は GitHub Settings → Developer settings → Personal access tokens → DEPLOY_TOKEN を `Issues: Read and Write` スコープで再発行すること（デプロイ用途の PAT とスコープが分離されている場合は注意）
- `ai_sns_plan.yml` で `git commit --allow-empty` を使うと空PRが作成され、auto_mergeがCopilot実装前に空PRをマージしてしまう → **正しい対処**: ①`auto_merge.yml` にマージ前の変更ファイル数チェック（空PRガード）を追加、②PRは `draft: true` で作成、③`--allow-empty` の代わりに `started_at` タイムスタンプ等の実ファイル変更をコミットする
- `ai_sns_plan.yml` で `@copilot` をPR本文（body）に書いても Copilot coding agent は起動しない → **正しい対処**: PR作成後に `issues.createComment` で別途PRコメントとして `@copilot` メンションを投稿する
- `pr_guardrails.yml` の必須セクション検証を全PR一律にすると、`copilot/ai-sns-*` / `auto-fix/*` / `deploy-failure/*` の自動起票PRが失敗する → **正しい対処**: 自動運用ブランチは本文テンプレ検証と §31 メタ検証を skip し、通常セッションPRのみ厳格検証する
- `plan_review.yml` でも同様に `@copilot` をIssue本文（body）に書いても起動しない → **正しい対処**: Issue作成後に `issues.createComment` で別途Issueコメントとして `@copilot` メンションを投稿する（DEPLOY_TOKEN使用）
- `plan_review.yml` の open Issue 重複チェックは7日超の古い Issue を自動クローズしてから新規作成する。Copilot 無反応で Issue が永久に open になり計画レビューがブロックされるのを防止する
- `weekly_pdca.yml` は `in_progress` 項目の `started_at` が7日以上前なら自動で `todo` にリセットする。Copilot 実装失敗やPR放置で WIP 上限に永久に達してしまうのを防止する
- `auto_merge.yml` は計画追加PRマージ後に `plan-review` ラベル付き open Issue を自動クローズする。plan_review → Copilot PR → auto_merge → Issue クローズ → 次の plan_review が起動可能になる
- Puma 8.x は `config/puma/{environment}.rb` が存在すると `config/puma.rb` を**読み込まない**（`find` で最初に見つかったファイルだけを使う）→ **正しい対処**: `config/puma/production.rb` に SolidQueue プラグイン設定（`plugin :solid_queue`, `solid_queue_mode :async`）と `.env` ロードを必ず含める。`config/puma.rb` にだけ書いても本番では効かない
- `config/puma/production.rb` で `workers N`（N>0）+ `preload_app!` を設定するとクラスターモード（fork）になり、SolidQueue async スレッドがfork後のワーカープロセスでジョブクラス解決に失敗して `ActiveJob::UnknownJobClassError` が繰り返し発生する → **正しい対処**: 単一VPSデプロイでは `workers` と `preload_app!` を削除してシングルプロセスモード（スレッドのみ）で動作させる
- デプロイ中の Puma 再起動時に SolidQueue recurring task が `ActiveJob::UnknownJobClassError` で一時的に失敗する → **正しい対処**: `config/initializers/active_job_unknown_class_retry.rb` で `ActiveJob::Base.deserialize` を prepend し、失敗時に `eager_load!` → リトライする。さらに管理画面の Failed Jobs 表示時にクラスがロード可能な一時的失敗は自動 discard する。deploy.yml では最終クリーンアップを 10 秒遅延で追加実行する
- `deploy.yml` の `workflow_run` トリガーが self-hosted runner 移行後に発火しなくなった（GitHub が push 時に全ワークフローの check suite を作成し、同コミットに対する workflow_run 実行がスキップされる）→ **正しい対処**: `ci.yml` に `dispatch_deploy` ジョブを追加し、main の CI 成功後に `deploy.yml` を `workflow_dispatch` で直接起動する（auto_merge.yml と同じ方式）。`deploy.yml` からは `workflow_run` トリガーを廃止済み（ノイズ削減）。`dispatch_deploy` にはリトライロジック（最大3回）を追加済み
- `bin/check_runner_health` の systemd サービス名が実際のサービス名と不一致だった → `./svc.sh install ubuntu` で作成されるサービス名はホスト名ベース（`actions.runner.kawauso29-myapp.os3-392-29108.service`）であり、ラベル名（`sakura-vps`）やユーザー名（`ubuntu`）ではない。VPS上で `systemctl list-units --type=service | grep actions.runner` で実際の名前を確認してから設定する
- **本番で何の通知も来ず recurring が完全に止まる症状の最有力原因は SolidQueue scheduler の無音停止**。`config/puma/production.rb` の SolidQueue plugin 起動を `if ENV["SOLID_QUEUE_IN_PUMA"]` で ENV ガードしていると、`.env` 読み込み失敗や変数欠落で plugin 自体が起動しなくなる。すると scheduler が消え、`config/recurring.yml` の全ジョブ（`MonitorFailedJobsJob` 5 分毎を含む）が走らず、失敗が起きても通知ゼロという無音故障に陥る。**正しい対処**: ①`config/puma/production.rb` は production 専用ファイルなので SolidQueue plugin は無条件起動（明示 opt-out は `SOLID_QUEUE_IN_PUMA=0`）、②`bin/check_solid_queue_alive` を VPS cron 5 分毎で実行し、scheduler プロセス不在 / 直近 30 分にジョブ enqueue ゼロを検知したら Slack ERROR 通知、③deploy.yml の末尾で `solid_queue:diagnose SLACK=1` を流してデプロイ直後の scheduler 起動状況を可視化する
- `Ledgers::ImprovementDetector` に `stale_ui_check` 検知ルールを追加した後、既存specが `detected == 1` を固定期待していると CI が失敗する → 既存ルールのspecでは `ui_check` の直近会議データを事前作成し、新ルール専用のspecだけで `stale_ui_check` 発火を検証する
- データ移行だけの migration（DDL変更なし）を追加したときも `db/schema.rb` の `version` は最新 migration 番号に更新される必要がある。schema version を更新せず migration ファイルだけをコミットすると CI の `test` / `job-check` / `route-check` で `ActiveRecord::PendingMigrationError` が発生する
- **Ledger 圧縮時間軸の正本は `Ledgers::TimeAxis::INTERVALS`** にハードコードされた固定値（daily=30分 / weekly=4時間 / monthly=12時間 / quarterly=2日 / annual=7日 / long_term=28日）。設計書 §11 / `thu_apr_16_2026_自律運営型ai企業体の設計.md` line 2309 の「4 年 = 28 日」圧縮を実装に落としたもの。値を変えるときはこの 1 か所のみ。Runner の `due_date` は `Ledgers::TimeAxis.due_date_for(cadence)`、`idempotency_key` は `Ledgers::IdempotencyKey.for_meeting(..., cadence:)` を必ず使う（同日中に複数回起動するサブ日 cadence で重複起票を冪等弾きするため）。`config/recurring.yml` の Ledger 系 cron も圧縮 interval（daily=30m → `*/30 * * * *`、weekly=4h → `0 */4 * * *`、monthly=12h → `0 */12 * * *`、quarterly=2d → `0 6 */2 * *`、annual=7d → `0 8 * * 0`）に揃える
- **Ledger Runner の cadence チェーン**（carry_over_items）: daily → weekly（hold_items）→ monthly（carry weekly）→ quarterly（carry monthly）→ annual（carry quarterly）。各 Runner は `previous_hold_items` private メソッドで前段の最新 hold_items を取得する
- **daily cadence は「会議なし種別」**（§12.6 選択肢A）: `DailyRunner` は KPI スナップショット取得・異常検知のみ行い、`chair_role: "system"` / `participants: []`。`DailyLedgerRunJob` は 30分周期で recurring.yml から起動
- self-hosted runner の永続DBで `create_table` migration がテーブル既存時に `PG::DuplicateTable` で失敗する → `create_table ... if_not_exists: true` と `add_index ... if_not_exists: true` を使い冪等にする
- `ENFORCE_TEMPLATE=1` / `TicketLedger.enforce_template = true` は `before_create :assert_template_present!` で `template_id` を必須化するが、`template_id` は `GithubMapping::CopilotInputTemplate#generate(ticket)` がチケット保存**後**に付与する設計のため、自動起票系（Runner/Detector/Planner/Feedback::Intake）の `TicketLedger.create!` は `template_id` を設定できず `RecordNotSaved` で落ちる。結果 `MeetingLedger` が `status: :open` のまま滞留し、以降のサイクルがブロックされる。→ Runner 系の自動チケット生成では `skip_template_guard: true` を明示的に渡して guard を bypass する（`QuarterlyReviewRunner` / `AnnualPlanRunner` / `WeeklyDeptRunner#create_ticket!` / `ImprovementDetector#create_ticket!` / `Reinforcements::Planner#create_improvement_ticket!` / `Feedback::Intake#maybe_escalate!`）。回帰テストは `spec/features/ledger_enforce_template_spec.rb`
- Copilot coding agent を Issue から起動するには `@copilot` コメントだけでなく、issueの **assignees に `copilot-swe-agent[bot]` を追加** することが必要。`GithubIssueService.add_assignees(issue_number:, assignees: ['copilot-swe-agent[bot]'], agent_assignment: { target_repo: REPO, base_branch: 'main', custom_instructions: '...' })` を呼ぶ。**`copilot` ではなく `copilot-swe-agent[bot]` が正しいユーザー名**（前者は無視される）。`agent_assignment` パラメータも必須。コメントは assignee 追加の**前**に投稿すること（Copilot はアサイン時点の既存コメントのみ読む）。`DEPLOY_TOKEN` には `Issues: Read and Write` に加えて `Actions: Read and Write`、`Contents: Read and Write`、`Pull requests: Read and Write` も必要。`TicketIssueSync#post_copilot_comment` で実装済み。
- **self-hosted runner OOM キルと自動再起動失敗（2026-04-26 実績）**: Copilot coding agent が `parallel_validation`（CodeQL）実行時に Java プロセスが 1.36GB 消費、1.9GB VPS で OOM キル発生。runner サービスは result: oom-kill で停止。`check_runner_health` の自動再起動も失敗した。**失敗の原因**: `sudo systemctl restart actions.runner...` が sudoers NOPASSWD に未登録のため、cron（TTY なし）から実行するとパスワード要求で失敗する。**2つの対処**:①OOM 再発防止: `$HOME/actions-runner/.env` に `JAVA_TOOL_OPTIONS=-Xmx600m` を追加し Java ヒープ上限を制限（`deploy.yml` の `Setup runner environment` ステップで自動設定）②sudo 権限の一時手動設定（一度だけ実行）: `echo 'ubuntu ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart actions.runner.kawauso29-myapp.os3-392-29108.service, /usr/bin/systemctl reset-failed actions.runner.kawauso29-myapp.os3-392-29108.service, /bin/systemctl restart actions.runner.kawauso29-myapp.os3-392-29108.service, /bin/systemctl reset-failed actions.runner.kawauso29-myapp.os3-392-29108.service' | sudo tee /etc/sudoers.d/github-runner-health && sudo chmod 440 /etc/sudoers.d/github-runner-health`
- **Copilot が `copilot/ai-sns-*` ではなく `copilot/copilotledger-*` ブランチで実装を完了したとき**: `copilot/ai-sns-*` ブランチの PR は変更ファイルが0件の空PRとして残り永久 open になる。plan status も done 更新されない。**対処**: ①`auto_merge.yml` の空PRガード（`merge_on_ci_pass` / `undraft_ai_sns_prs` スケジュール）が空の ai-sns-* PRを自動クローズする（修正済み）。②plan status を本番DBで手動更新: `cd ~/myapp && RAILS_ENV=production bin/rails runner "t = TicketLedger.find_ai_sns_plan_by_item_key('KEY'); t.skip_template_guard=true; t.skip_lane_capacity_guard=true; t.skip_pr_guardrail=true; t.skip_stop_guard=true; t.update!(status: :completed)"`
