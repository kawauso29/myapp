# GitHub Copilot Instructions

**回答は必ず日本語で行うこと。**

このリポジトリは Ruby on Rails 8.1 のモノリスです。
**Linestamp（LINEスタンプ工房）** と **Picro 通知** の 2 機能だけを残した剪定後の構成で、過去に存在していた AI SNS / Ledger / LedgerV2 / Trading の各サブシステムは削除済みです。

剪定範囲の正本は `docs/PRUNE_KEEP_SCOPE.md` を参照すること。範囲外のシステムをこのリポジトリに復活させないでください。

## プロジェクト概要

- **バックエンド**: Ruby 3.3.7 / Rails 8.1.2
- **DB**: PostgreSQL（本番: `myapp_production`）
- **キュー**: SolidQueue（Puma 同居、`SOLID_QUEUE_IN_PUMA=1`）
- **キャッシュ / Cable**: SolidCache / SolidCable
- **本番サーバー**: さくら VPS（Ubuntu 22.04 / Nginx + Puma）
- **テスト**: RSpec

## ドキュメント連動更新ルール

- `.github/copilot-instructions.md` と `CLAUDE.md` は連動ドキュメントとして扱う
- 運用ルールを更新したら、必ず両方を同時に更新する

## コーディングルール（Ruby / Rails）

### やってはいけないこと（CI で必ず引っかかる）

- `Time.now` → **`Time.current`**（Rails/TimeZone cop）
- `"str" + method()` → **`"str#{method()}"`**
- `head :unauthorized and return` → **`return head :unauthorized`**
- private ブロック内の定数定義 → private より前に定義する
- `Redis.current`（Redis 5.x で廃止）→ **`$redis`**（`config/initializers/redis.rb`）

### 必須

- 新規 / 変更コードには RSpec テストを付ける
- 定期実行ジョブを追加 / 改名したら以下に同時反映する:
  - `config/recurring.yml`
  - `config/initializers/required_job_classes.rb`
  - `lib/tasks/solid_queue.rake` の `REQUIRED_JOB_CLASSES`
  - 対応する `*_job_spec.rb`

### データ migration

`bin/rails generate data_migration <名前>` で冪等テンプレートを生成し、以下を守る:

1. 冪等に書く（`find_or_create_by!` / `upsert` / `update_columns ... WHERE xxx IS NULL`）
2. `down` を必ず書く（不可逆な場合は `raise ActiveRecord::IrreversibleMigration`）
3. `db/schema.rb` の `version` を必ず更新する
4. モデルに依存する操作は `update_columns` / SQL 直書きでコールバックを bypass

健全性チェック: `bin/rails db:migrate:lint`

## PR 作成

1. 変更内容を Linestamp / Picro / 共通基盤のどれに該当するか明示する（範囲外のシステムを復活させない）
2. `bin/rubocop` で Lint OK
3. `bundle exec rspec` で全 spec OK
4. PR を作成

## セッションモード（自動マージ）

`create_pr.yml` がブランチ名で判定する:

| ブランチパターン | session-hold | 動作 |
|---|---|---|
| `copilot/auto-*` | 付けない | CI 通過で即マージ＆デプロイ |
| `auto-fix/*` | 付けない | CI 通過で即マージ |
| `claude/*` / `copilot/*`（上記以外） | 付ける | 会話完了後にラベルを外すと auto_merge.yml が発火 |

## 通知のルーティング

| カテゴリ | 用途 | Secret |
|---|---|---|
| ① CI/Deploy 進捗 | CI 成功/失敗、デプロイ開始/成功 | `SLACK_WEBHOOK_URL_CI` |
| ② エラー | デプロイ失敗、アプリ例外、監視アラート | `SLACK_WEBHOOK_URL_ERROR` |
| ③ ジョブ/アクション結果 | Auto Fix / Auto Merge / Auto PR の結果 | `SLACK_WEBHOOK_URL_JOBS` |

詳細は `docs/slack-notification-routing.md`。
