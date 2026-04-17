# Slack通知ルーティング

通知の送信先を運用しやすくするため、**送信元ごとのチャネル割り当て**をこのファイルで管理する。

## チャネルカテゴリ

| カテゴリ | 用途 | Secret |
|---|---|---|
| ① CI/Deploy進捗 | CI成功/失敗、デプロイ開始/成功、定期運用の進捗 | `SLACK_WEBHOOK_URL_CI` |
| ② エラー | デプロイ失敗、アプリ例外、監視アラート | `SLACK_WEBHOOK_URL_ERROR` |
| ③ ジョブ/アクション結果 | Auto Fix/Auto Merge/Auto PR などの運用結果、AI投稿系の運用ログ | `SLACK_WEBHOOK_URL_JOBS` |

## 送信元ごとの割り当て

| 送信元 | 通知内容 | カテゴリ |
|---|---|---|
| `ci.yml` notify success | CI passed | ① |
| `ci.yml` notify failure | CI failed | ① |
| `deploy.yml` deploy start/success | デプロイ開始/成功 | ① |
| `deploy.yml` deploy failure | デプロイ失敗 | ② |
| `post_deploy_cleanup.yml` deploy failure PR created | デプロイ失敗PR起票 | ② |
| `auto_fix.yml` | auto-fix結果、CI triage | ③ |
| `auto_merge.yml` | auto-merge結果、deploy dispatch失敗、計画完了通知 | ③（マージ結果）/ ①（計画完了）|
| `auto_create_pr.yml` / `pr_ci_fix.yml` | 自動PR関連通知 | ③ |
| `weekly_pdca.yml` / `ai_sns_plan.yml` | 定期運用通知 | ① |
| `plan_review.yml` | 計画レビュー自動起票通知 | ① |
| Rails `SlackNotifierService`（`channel: :error`） | アプリ例外、ジョブ失敗、レート制限 | ② |
| Rails `SlackNotifierService`（`channel: :jobs`） | AI投稿/リプライ/DM/ライフイベント等の運用ログ | ③ |

## 運用ルール

- RailsアプリのWebhookは `deploy.yml` の `Sync Slack env vars to VPS` で同期する
- `channel: :jobs` の通知は `SLACK_WEBHOOK_URL_JOBS` 未設定時に **error へフォールバックしない**
- ルーティングを変更したら、このファイル・`CLAUDE.md`・`.github/copilot-instructions.md` を同時更新する
