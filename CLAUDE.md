# CLAUDE.md

Claude Code向けのプロジェクトメモ。

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

## Slack通知 3カテゴリ設計

### カテゴリ定義と送信先

| カテゴリ | 内容 | GitHub Secret | VPS .env |
|---|---|---|---|
| ① CI/Deploy進捗 | CI成功, デプロイ開始/成功, PR通知 | `SLACK_WEBHOOK_URL_CI` | 不要（GitHub Actionsのみ） |
| ② エラー | CI失敗, デプロイ失敗, アプリ障害, レート制限 | `SLACK_WEBHOOK_URL_ERROR` | `SLACK_WEBHOOK_URL_ERROR` |
| ③ ジョブ/アクション結果 | auto-fix PR作成, auto-merge結果, triage issue通知 | `SLACK_WEBHOOK_URL_JOBS` | 不要（GitHub Actionsのみ） |

### フォールバック仕様

各シークレットが未設定の場合、既存の `SLACK_WEBHOOK_URL` にフォールバックする（後方互換）。
新しいシークレットを追加することでチャンネルを分離できる。

### ワークフロー別マッピング

| ワークフロー | 通知 | カテゴリ |
|---|---|---|
| `ci.yml` notify success | CI passed | ① |
| `ci.yml` notify failure | CI failed | ② |
| `deploy.yml` start/success | デプロイ開始/成功 | ① |
| `deploy.yml` failure | デプロイ失敗 | ② |
| `auto_fix.yml` | auto-fix PR作成/lint失敗 | ③ |
| `auto_fix.yml` triage_ci_failures | test/check系CI失敗Issue | ③ |
| `pr_ci_fix.yml` | PR CI自動修正結果 | ③ |
| `post_deploy_cleanup.yml` create_deploy_failure_issue | デプロイ失敗Issue起票 | ② |
| `auto_merge.yml` | auto-merge失敗 | ③ |

### アプリ側（SlackNotifierService）

`SlackNotifierService` はカテゴリ② 専用。VPS `.env` に `SLACK_WEBHOOK_URL_ERROR` を設定する。
`deploy.yml` の env sync ステップで `SLACK_WEBHOOK_URL_ERROR` を自動的にVPSへ書き込む。

### Slackからの自動修正ルートについて

Slack→Copilot自動修正（`SlackEventsController` → `SlackForwardToClaudeJob`）は
**カテゴリ② のエラーメッセージ専用**に限定する。
CI進捗通知などはここに流さない（`forwardable_message?` のフィルタで制御）。
自動起動は補助機能扱いで、主経路はIssue/PRコメント起票とする。

## CI自動リカバリーシステム

### 仕組みの概要

```
main への push
    ↓
[CI ワークフロー] （scan_ruby / scan_js / lint / test / system-test）
    ↓ 成功                        ↓ 失敗
[Deploy ワークフロー]          [Auto Fix ワークフロー]
  ↓ ヘルスチェック               ↓ rubocop --autocorrect
  ↓ 失敗                         ↓ 自動修正PRを作成 + Slack通知
  ↓ ロールバック実行
  ↓ Slack通知（原因・次アクション付き）
```

### デプロイゲート（deploy.yml）

- `main` push だけでデプロイが走らない。**CI が全ジョブ成功した後にのみ** deploy.yml が起動する
- トリガー: `workflow_run: workflows: ["CI"], types: [completed]`
- `workflow_dispatch` で手動デプロイは引き続き可能

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
- 本番で `MonitorFailedJobsJob` のSlack通知が来ない場合、VPS `.env` に `SLACK_WEBHOOK_URL_ERROR` が同期されているか確認する（旧 `SLACK_WEBHOOK_URL`。`deploy.yml` が自動同期するが未設定の場合は手動で `SLACK_WEBHOOK_URL_ERROR=<webhook>` を追記）
- `ActiveJob::UnknownJobClassError` が継続する場合、**誤り**: systemdのsolid_queueサービスを再起動 → **正しい**: solid_queueは `SOLID_QUEUE_IN_PUMA=1` でPuma内で動作しているため別途再起動不要。Pumaの再起動後に十分な待機時間（10秒）を確保し、その後 `eager_load!` を実行する
- `ActiveJob::UnknownJobClassError` 再発時、legacyジョブ停止のPID抽出が `$2/$3 == bin/jobs` だけだと `bundle exec bin/jobs` を取りこぼす。`ps -eo pid,args | awk` でコマンド全体を正規表現マッチして停止対象を拾う
- legacy `bin/jobs` 停止処理で `ps ... args` の全文一致だけを使うと、`ssh-action` 実行中の `bash -c`（スクリプト本文に `bin/jobs` を含む）まで誤検知して自己終了(143)することがある → `ps -eo pid,comm,args` で `bash/sh` を除外し、さらに `$$` と `$PPID` を kill 対象から除外する
