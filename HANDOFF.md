# myapp プロジェクト引き継ぎメモ

## プロジェクト概要

Rails モノリス。**Linestamp** と **Picro 通知** の 2 機能だけを残した剪定後の構成。
基本情報は `README.md` を参照。

## デプロイ先（さくら VPS）

| 項目 | 値 |
|---|---|
| サーバー | さくら VPS（Ubuntu 22.04） |
| IP | 133.167.124.112 |
| アプリパス | `/home/ubuntu/myapp` |
| DB | PostgreSQL（DB 名: `myapp_production`、ユーザー: `ubuntu`） |
| Ruby | 3.3.7（rbenv） |
| Rails | 8.1.2 |
| Web | Nginx → Puma（Unix ソケット） |

## 自動デプロイ

`main` ブランチに push すると GitHub Actions（`.github/workflows/deploy.yml`）が起動し、さくら VPS に SSH してデプロイする。

```
git fetch origin main
git reset --hard origin/main
bundle install
RAILS_ENV=production bin/rails db:migrate
RAILS_ENV=production bin/rails assets:precompile
rm -rf tmp/cache/*
sudo systemctl restart puma
```

## 認証情報

`.env` または GitHub Secrets で以下を管理する:

| キー | 用途 |
|---|---|
| `DATABASE_URL` | DB 接続 |
| `RAILS_MASTER_KEY` | Rails credentials の復号 |
| `ANTHROPIC_API_KEY` | LLM 呼び出し |
| `LINE_CHANNEL_SECRET` / `LINE_CHANNEL_ACCESS_TOKEN` | LINE Messaging API |
| `LINE_USER_ID` | LINE 通知の宛先（自分） |
| `PICRO_LOGIN_ID` / `PICRO_PASSWORD` | Picro スクレイピング |
| `SLACK_WEBHOOK_URL_CI` / `SLACK_WEBHOOK_URL_ERROR` / `SLACK_WEBHOOK_URL_JOBS` | Slack 通知 3 系統 |
| `SLACK_SIGNING_SECRET` / `SLACK_BOT_TOKEN` | Slack Events API |

詳しいセットアップは `docs/picro_setup.md` と `docs/linestamp/` を参照。

## Slack 自動転送

エラー通知チャネルのメッセージを `SlackEventsController` で検知し、GitHub Copilot Slack アプリに DM 転送する（`SlackForwardToClaudeJob`）。仕様は `docs/slack-notification-routing.md`。

## テスト

```bash
bundle exec rspec
```

CI（`.github/workflows/ci.yml`）でも自動実行される。
