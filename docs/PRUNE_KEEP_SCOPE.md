# 剪定スコープ（KEEP / REMOVE）

このリポジトリは `Linestamp + Picro 通知` だけを残した単機能モノリスとして運用する。
今後の作業はこのスコープを境界として行うこと。

## KEEP（残す）

| 系統 | 名前空間 / モジュール | 主な実体 |
|---|---|---|
| Linestamp | `Linestamp::` | `app/controllers/{admin,api/v1}/linestamp/`、`app/controllers/linestamp/`、`app/models/linestamp/`、`app/jobs/linestamp/`、`app/services/linestamp/`、`app/views/admin/linestamp/`、`config/routes.rb` の `namespace :linestamp` |
| Picro 通知 | `picro` / `Picro` | `app/models/picro_message.rb`、`app/services/picro_scraper_service.rb`、`app/jobs/picro_check_job.rb`、`app/controllers/admin/picro_notifications_controller.rb`、`app/views/admin/picro_notifications/`、`config/recurring.yml` の `picro_check` |
| 共通基盤 | — | 認証（Devise/JWT）、Admin 共通レイアウト、Slack 連携、Claude ターミナル、LLM ゲートウェイ、ActiveStorage |

## REMOVE（削除済み）

| 系統 | 削除理由 |
|---|---|
| AI SNS（`ai_*` モデル群、daily/moderation/events サービス、`global_timeline_channel` 等） | 単機能化のため範囲外 |
| Ledger / LedgerV2（運営 OS。台帳・Runner・組織ロール・KPI スナップショット等） | 単機能化のため範囲外 |
| Trading（`market_snapshots` / `trade_decisions` / `trade_results` / `analysis_reports` / `agent_judgments`） | 単機能化のため範囲外 |
| 上記に依存する controllers / models / jobs / services / routes / admin ナビ / workflows / docs / spec | 連鎖削除 |

## 運用ルール

- **参照（routes / admin nav / workflows）を消してから実体を消す**：壊れる箇所が広がるのを防ぐ
- **1 系統ずつコミット**：原因切り分けを最優先
- 範囲外のシステムをこのリポジトリに復活させない（新規にやるなら別リポを立てる）
- LLM 呼び出しの ENV キーは `LLM_CREATION_MODEL` / `LLM_POST_MODEL` を使う（旧 `AI_SNS_*` は廃止）
