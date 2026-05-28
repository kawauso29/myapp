# myapp

Rails モノリス。**Linestamp**（LINEスタンプ工房）と **Picro 通知** の 2 つの機能だけを残した剪定後の構成。

## 機能

| 機能 | 概要 | 主な場所 |
|---|---|---|
| **Linestamp** | LINEスタンプの調査・ブランド設計・パック/スタンプ生成・LINE Webhook 連携 | `app/**/linestamp/`、`config/routes.rb` の `namespace :linestamp` |
| **Picro 通知** | Picro の新着メッセージをスクレイピングして LINE 通知 | `app/jobs/picro_check_job.rb`、`app/services/picro_scraper_service.rb`、`app/models/picro_message.rb` |

## アーキテクチャ

```
Rails 8.1 (Ruby 3.3.7)
├─ Linestamp 系 …… 管理画面 `/admin/linestamp`、API `/api/v1/linestamp`、LINE Webhook
├─ Picro 通知 ……… 15 分ごとに `PicroCheckJob`（SolidQueue recurring）
├─ Slack 連携 ……… `/slack/events`、`/slack/commands`
├─ Claude Terminal … `/claude`（ActionCable 経由の PTY）
└─ 管理画面 ……… `/admin`（Repository、Picro、Linestamp）
```

## 主要技術スタック

| カテゴリ | 採用技術 |
|---|---|
| Ruby/Rails | Ruby 3.3.7 / Rails 8.1.2 |
| DB | PostgreSQL |
| Job Queue | SolidQueue（Puma 同居） |
| Cache/Cable | SolidCache / SolidCable |
| 認証 | Devise + devise-jwt |
| Web | Puma + Nginx（Unix ソケット） |
| 通知 | LINE Messaging API、Slack Webhook |
| LLM | Anthropic Claude（`LlmClient` / `Llm::Gateway`） |
| テスト | RSpec |

## ローカル開発（Docker）

```bash
docker compose up
# Rails: http://localhost:3000
# DB:    PostgreSQL 16
# Redis: localhost:6379
```

## 主な URL

| URL | 用途 |
|---|---|
| `/` | トップ |
| `/admin` | 管理画面（Repository ダッシュボード） |
| `/admin/picro_notifications` | Picro 通知履歴 |
| `/admin/linestamp` | Linestamp 管理 |
| `/api/v1/linestamp/search` | Linestamp 検索 API |
| `/linestamp/webhooks/line_review` | LINE 審査 Webhook |
| `/slack/events`, `/slack/commands` | Slack Events / Slash Command |
| `/claude` | Claude ターミナル（開発用） |
| `/cable` | ActionCable |

## ドキュメント

- `docs/linestamp/` — Linestamp の設計・運用ドキュメント一式
- `docs/picro_setup.md` — Picro 通知のセットアップ手順
- `docs/slack-notification-routing.md` — Slack 通知のルーティング設計
- `docs/projects/github-actions-migration.md` — self-hosted runner 移行の記録
- `docs/PRUNE_KEEP_SCOPE.md` — 剪定範囲（KEEP / REMOVE）の定義

## 剪定履歴

このリポジトリは「Linestamp + Picro」だけを残した剪定後の状態です。剪定前に存在していた以下のサブシステムは取り除かれています:

- AI SNS（`ai_users` 系、投稿/DM/関係性などの台帳）
- Ledger / LedgerV2（運営 OS、会議台帳、KPI 台帳等）
- Trading（取引判断/結果系）

剪定方針は `docs/PRUNE_KEEP_SCOPE.md` を参照してください。
