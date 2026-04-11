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

## Slack自動転送システム（SlackEventsController）

### 概要

エラー通知チャネルのメッセージを検知し、Claudeチャネルに `@GitHub` メンション付きで自動転送する。

- エンドポイント: `POST /slack/events`
- 転送ジョブ: `SlackForwardToClaudeJob`

### 必要なGitHub Secrets（デプロイ時にVPSの.envに自動書き込み）

| Secret名 | 内容 |
|----------|------|
| `SLACK_SIGNING_SECRET` | Slack App → Basic Information → Signing Secret |
| `SLACK_BOT_TOKEN` | Slack App → OAuth & Permissions → Bot User OAuth Token（xoxb-...）|
| `SLACK_ERROR_CHANNEL_ID` | 監視対象チャネルのID（Cxxxxx）|
| `SLACK_CLAUDE_CHANNEL_ID` | 転送先ClaudeチャネルのID |
| `SLACK_GITHUB_MEMBER_ID` | GitHub Slack AppのメンバーID（`@GitHub` を実際のメンションにするために必要。Slackで `/who @GitHub` などでIDを確認するか、Slack APIで `users.list` を叩いて取得）|

### Slack App設定

- Bot Token Scopes: `channels:history`, `chat:write`
- Event Subscriptions → Request URL: `https://133.167.124.112/slack/events`
- Subscribe to bot events: `message.channels`
- BotをエラーチャネルとClaudeチャネル両方に `/invite` すること

### 重要な注意点・ハマりポイント

**エラー通知はBotメッセージ**
- `myapp-notify` はIncoming Webhook経由のBotとして投稿する
- `bot_id` チェックで除外するとエラー通知が転送されない（ハマった）
- **正しい実装**: `bot_id` チェックは行わず、キーワードフィルタで判定する
- `subtype` の一括チェックも NG。`bot_message` サブタイプも弾いてしまう
- 除外すべき subtype は `message_changed`, `message_deleted`, `channel_join`, `channel_leave` のみ明示的に指定する

**`@GitHub` メンションが文字列になる問題**
- Slack APIで `@GitHub` をテキストに含めても、それは単なる文字列になる（2026-04-12確認）
- 正しい方法: GitHub Slack AppのメンバーIDを取得して `<@MEMBER_ID>` 形式で送信する
- 実装: `SLACK_GITHUB_MEMBER_ID` env var を設定すると `<@id>` 形式に、未設定なら `@GitHub` + `link_names: true` フォールバック
- メンバーIDの取得方法: Slack ワークスペースの管理画面 or `https://api.slack.com/methods/users.lookupByEmail` や `users.list` APIで確認

**ループ防止**
- 転送先はClaudeチャネル（`SLACK_CLAUDE_CHANNEL_ID`）のみに投稿
- エラーチャネル（`SLACK_ERROR_CHANNEL_ID`）には絶対に書き込まない

### ローカル開発環境（Docker）

```bash
docker compose up
```

- Rails: http://localhost:3000
- DB: PostgreSQL 16（`postgres:password@localhost:5432`）
- Redis: localhost:6379
- 設定: `docker-compose.yml` + `Dockerfile.dev`

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
