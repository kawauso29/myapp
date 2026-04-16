# 会議入力テンプレート / Meeting Input Template

`meeting_ledgers` の新規実行・事後記録に使う標準入力です。

## 必須項目 / Required Fields

```yaml
request_id: "meeting-weekly_dept-2026-04-16-ai_sns" # 冪等キー（同一実行の重複防止）
meeting_key: "weekly_dept" # weekly_dept | monthly_ops | quarterly_review | annual_plan
meeting_type: "weekly" # 推奨: long_term | annual | quarterly | monthly | weekly | incident
service_key: "ai_sns" # 運用キー（DB保存時は service_id に対応）
scope_level: "service" # company | portfolio | service | cross_service
held_at: "2026-04-16T09:00:00+09:00"
chair: "ops_lead"
status: "closed" # open | closed | followup_pending
agenda_summary:
  - "先週のKPI確認"
  - "overdueチケットの解消方針"
decisions:
  - "投稿失敗率>3%のため改善チケットを起票"
linked_kpis:
  - "post_success_rate"
  - "overdue_ticket_rate"
```

## 記入例 / Example

```yaml
request_id: "meeting-monthly_ops-2026-04-30-platform"
meeting_key: "monthly_ops"
meeting_type: "monthly"
service_key: "platform"
scope_level: "company"
held_at: "2026-04-30T18:00:00+09:00"
chair: "monthly_ops_runner"
status: "closed"
agenda_summary:
  - "4月運用レビュー"
  - "改善チケット進捗確認"
decisions:
  - "高優先度チケット2件を翌月W1で完了する"
linked_kpis:
  - "service_health"
```

## 冪等性メモ / Idempotency Notes

- `request_id` を必須化し、同一キーは再実行時に「更新扱い」にする
- `meeting_key + held_at + service_key` の組み合わせ重複をチェックする

> 補足: `quarterly_review` / `annual_plan` は会議種別を表す `meeting_key` として使います。`meeting_type` は運用入力の標準化のため、`meeting_key=quarterly_review` でも `quarterly`、`meeting_key=annual_plan` でも `annual` を推奨します（DB enum には拡張値が存在しても入力値は単純化する方針）。

| meeting_key | 推奨 meeting_type |
|---|---|
| weekly_dept | weekly |
| monthly_ops | monthly |
| quarterly_review | quarterly |
| annual_plan | annual |

## 監査性メモ / Auditability Notes

- 実行後に `meeting_ledger.id`、実行時刻、実行者を追記する
- 判断理由（なぜその決定か）を `decisions` に残す
