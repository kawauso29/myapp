# 起票入力テンプレート / Ticket Input Template

会議決定を `ticket_ledgers` に反映するための標準入力です。

## 必須項目 / Required Fields

```yaml
request_id: "ticket-weekly_dept-2026-04-16-ai_sns-overdue_rate"
source:
  meeting_key: "weekly_dept"
  source_meeting_type: "weekly" # long_term | annual | quarterly | monthly | weekly | incident
  source_meeting_id: 123
service_key: "ai_sns" # DB保存時は service_id に対応
kpi_key: "overdue_ticket_rate"
ticket_type: "improvement" # operations | audit | quarterly_review | annual_plan | improvement
title: "overdue率上昇の是正"
status: "planned" # draft | approved | planned | executing | waiting_review | completed | cancelled | overdue
priority: "high" # low | medium | high
scope_level: "service" # company | portfolio | service
escalation: "monthly" # monthly | quarterly | annual | long_term
due_date: "2026-04-23"
assignee: "ai_sns_owner"
rationale: "overdue率25%が閾値20%を超過したため"
linked_kpis:
  - "overdue_ticket_rate"
```

> 補足: `ticket_ledger` の `scope_level` は `company | portfolio | service` のみです（`cross_service` は `meeting_ledger` 側の値）。
> 補足: DB enum 上は `ops` も有効値ですが、このテンプレートでは新規入力の標準化のため allowed values から意図的に除外しています。新規作成・更新は `operations` を使用してください。既存データに `ops` が残っている場合は読み取り互換として許容し、必要に応じて `operations` へ移行します。

## 記入例 / Example

```yaml
request_id: "ticket-monthly_ops-2026-04-30-platform-service_health"
source:
  meeting_key: "monthly_ops"
  source_meeting_type: "monthly"
  source_meeting_id: 456
service_key: "platform"
kpi_key: "service_health"
ticket_type: "operations"
title: "夜間バッチ遅延の再発防止"
status: "approved"
priority: "medium"
scope_level: "service"
escalation: "quarterly"
due_date: "2026-05-15"
assignee: "platform_ops"
rationale: "月次レビューで3回連続遅延を確認"
linked_kpis:
  - "service_health"
  - "batch_success_rate"
```

## 冪等性メモ / Idempotency Notes

- `request_id` を一意キーとして、再送時は同一チケットを更新する
- `source_meeting_id + ticket_type + title` の重複起票を事前チェックする

## 監査性メモ / Auditability Notes

- 変更時は `status` の遷移理由を `rationale` に残す
- `assignee`, `due_date`, `escalation` の変更履歴を残せる形で運用する
