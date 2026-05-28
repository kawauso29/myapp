# CLAUDE.md

Claude Code / Copilot 向けのプロジェクトメモ。

## プロジェクトの現在の状態

このリポジトリは **Linestamp（LINEスタンプ工房）** と **Picro 通知** だけを残した剪定後の単機能モノリスです。  
過去に存在していた **AI SNS / Ledger / LedgerV2 / Trading** の各サブシステムは削除済み。今後の作業もこの 2 機能の維持・拡張に絞ること。

剪定範囲の正本: `docs/PRUNE_KEEP_SCOPE.md`

## Claude Code / Copilot への指示

### コマンドの提示方法

ユーザーはスマホから SSH でコマンドを実行することが多い。マルチライン（複数行）はコピペで崩れやすい。

- 1 行のワンライナーを優先する
- どうしても複数行になる場合はスクリプトファイル化して `bash script.sh` で実行する

### メモの更新ルール

- 重要な情報が出てきたら必ず CLAUDE.md に追記する
- 間違いを指摘されたら、その内容と正しい情報を CLAUDE.md に記録する
- `.github/copilot-instructions.md` と CLAUDE.md は連動管理する

### main へのマージ・push

作業完了後は必ず main にマージ・push する。

- フィーチャーブランチで作業した後は `git checkout main && git merge <branch> && git push origin main`
- ローカル main が origin/main と乖離している場合は `git fetch origin main && git reset --hard origin/main` で同期してからマージ

## デプロイ仕様

### 自動デプロイのトリガー

`main` ブランチに push すると `.github/workflows/deploy.yml` が起動し、さくら VPS にデプロイする。

### デプロイ先

| 項目 | 値 |
|---|---|
| サーバー | さくら VPS（Ubuntu 22.04） |
| IP | 133.167.124.112 |
| ユーザー | ubuntu |
| アプリパス | `/home/ubuntu/myapp` |
| Ruby | 3.3.7（rbenv） |
| Rails | 8.1.2 |
| Web | Nginx → Puma（Unix ソケット `tmp/sockets/puma.sock`） |
| DB | PostgreSQL（`myapp_production`、ユーザー: `ubuntu`） |

### デプロイ手順（GitHub Actions が自動実行）

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

### GitHub Secrets

| Secret | 内容 |
|---|---|
| `VPS_HOST` | 133.167.124.112 |
| `VPS_USER` | ubuntu |
| `VPS_SSH_KEY` | GitHub Actions 用 ed25519 秘密鍵 |
| `SLACK_WEBHOOK_URL_CI` / `SLACK_WEBHOOK_URL_ERROR` / `SLACK_WEBHOOK_URL_JOBS` | Slack 通知 |
| `SLACK_SIGNING_SECRET` / `SLACK_BOT_TOKEN` / `SLACK_ERROR_CHANNEL_ID` / `SLACK_GITHUB_MEMBER_ID` | Slack Events API |
| `ANTHROPIC_API_KEY` | LLM 呼び出し |

### 502 エラー時のデバッグ

```bash
cd ~/myapp && RAILS_ENV=production rails runner "puts 'OK'" 2>&1 | head -5
```

- エラーが出る → Rails が起動できていない（Syntax エラー等）
- "OK" → Puma / Nginx の設定問題

Puma 再起動: `sudo systemctl restart puma`

## Slack 自動転送（SlackEventsController）

エラー通知チャネルのメッセージを検知し、GitHub Copilot Slack アプリに DM 転送する。

- エンドポイント: `POST /slack/events`
- 転送 Job: `SlackForwardToClaudeJob`

詳細は `docs/slack-notification-routing.md` を参照。

## ローカル開発

```bash
docker compose up
# Rails: http://localhost:3000
# DB:    PostgreSQL 16
# Redis: localhost:6379
```

## PR 作成

### PR 作成前の確認

1. 変更が Linestamp / Picro / 共通基盤のいずれに影響するかを確認する（範囲外のシステムをこのリポジトリに復活させない）
2. `bin/rubocop` で Lint エラーがないことを確認
3. `bundle exec rspec` でテストが通ることを確認
4. PR を作成

### セッション継続モード（自動マージの停止）

- **CI 通過 → 自動マージ → 自動デプロイ** が基本動作（デフォルト）
- 対話セッション中のブランチのみ `session-hold` ラベルで一時停止する

| ユーザーの指示例 | モード | ブランチ命名 |
|---|---|---|
| 「デプロイまで進めて」「自動でやって」「おまかせ」 | 自動完走 | `copilot/auto-{内容}` |
| 「相談したい」「確認しながら」（指定なし含む） | 対話 hold（デフォルト） | `copilot/{内容}` |

`create_pr.yml` がブランチ名で判定し、対話セッションには `session-hold` ラベルを自動付与する。会話完了後にラベルを外すと `auto_merge.yml` の `unlabeled` トリガーが発火してマージ＆デプロイされる。

## CI で過去にハマった点（記録）

- `actions/checkout@v6` は存在しない → `@v4` を使う
- `head :unauthorized and return` は RuboCop 違反 → `return head :unauthorized`
- private ブロック内に定数を定義すると RuboCop 警告 → private より前に定義
- `Time.now` は Rails/TimeZone 違反 → `Time.current` を使う
- `Redis.current` は Redis 5.x で廃止 → `$redis`（`config/initializers/redis.rb`）
- テスト環境で `Rack::Attack` のレート制限が干渉する → `Rails.env.test?` で `enabled = false`
- `line-bot-api` 2.7 には `Line::Bot::Client` が存在しない → `Line::Bot::V2::MessagingApi::ApiClient` + `*_with_http_info`
- `enum :status, { ... }, prefix: true` のスコープ名は `status_pending` 等（`prefix: true` を見落とすと CI 失敗）
- self-hosted runner では `jq` が無い → `python3 -c "import json, os ..."` を使う
- `@github-copilot` ではなく **`@copilot`** をメンションに使う
- `GITHUB_TOKEN` で作成したコメントは Copilot coding agent の Webhook をトリガーしない → `DEPLOY_TOKEN`（fine-grained PAT、`Issues: Read and Write`）を使う
- Puma 8.x は `config/puma/{environment}.rb` があると `config/puma.rb` を読まない → `config/puma/production.rb` に SolidQueue 設定を必ず置く
- 単一 VPS では `workers N` + `preload_app!` を避け、シングルプロセスモードで動かす（fork すると SolidQueue async でクラス解決に失敗する）

## Linestamp 運用メモ

### 企画ファイルは Brand + 初回 Pack(8 stamps) を 1 ファイルに同梱する

- 1 ブランド = 1 ファイル = `Linestamp::Importer.run` ブロック内で `upsert_brand!` → `attach_*` → `create_pack!(stamps: [...8件...])` を続けて記述する
- 雛形: `db/seeds/linestamp/imports/_templates/brand_template.rb`
- Pack を別ファイルに切り出すと、apply_imports のトランザクション境界が分かれてプロンプト自動合成のタイミングが揃わなくなるので必ず同梱する
- 追加で Pack を増やしたい場合のみ `pack_template.rb` を使って別ファイル投入を許可（緊急時の追加投入専用）

### プロンプトはレコード作成時に自動合成される

- `Linestamp::Brand` / `Pack` / `Stamp` の `after_commit on: :create` フックが `Compose*PromptJob` を `perform_later` する
- `apply_imports` rake タスクは `ActiveRecord::Base.transaction` で eval を囲んでいるため、CT/属性 attach 完了後の単一コミットで Brand → Pack → Stamps の after_commit が順に発火する
- 企画ファイル側で `brand_prompt` / `sheet_prompt` / `prompt` を直接埋めない（埋めると after_commit のガード `prompt.blank?` で何も起きなくなる）
- cron 経路（DailyOrchestratorJob / `config/schedule.yml`）は廃止済み。SolidQueue は `config/recurring.yml` のみ読む

### マスタ slug 整合性

- 各 stamp の `primary_communication_theme` は **Brand に紐づけた `attach_communication_themes!` の slug のいずれかと一致** させる
- 未知 slug は `ArgumentError: Unknown CommunicationTheme slug` で apply_imports が失敗するので、事前に `bin/rails runner 'puts Linestamp::CommunicationTheme.pluck(:slug,:name)'` で確認する

## データ migration ガイド

Rails 標準の `bin/rails db:migrate` を使う。デプロイフローに組み込み済み。

1. **冪等に書く**: `find_or_create_by!` / `upsert` / `update_columns ... WHERE xxx IS NULL`
2. **`down` を必ず書く**: 不可逆な場合は `raise ActiveRecord::IrreversibleMigration`
3. **`db/schema.rb` の `version` を必ず更新する**: DDL なしのデータ操作 migration でも更新が必要
4. **モデルに強く依存する操作は `update_columns` / SQL 直書きを使う**: コールバックを bypass

ジェネレーター: `bin/rails generate data_migration <名前>`  
健全性チェック: `bin/rails db:migrate:lint`
