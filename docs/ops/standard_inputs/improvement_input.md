# 改善シグナル入力テンプレート / Improvement Signal Input Template

改善チケットの「検知条件」「期待結果」「解消手順」を標準化する入力です。

## 必須項目 / Required Fields

```yaml
request_id: "improvement-overdue-rate-ai_sns-2026w16"
improvement_key: "overdue_rate_control"
service_key: "ai_sns"
meeting_key: "weekly_dept"
status: "active" # active | monitoring | resolved | archived
signal_summary: "overdue率が連続で閾値超過"
detection_criteria:
  metric: "overdue_ticket_rate"
  operator: ">"
  threshold: 0.20
  lookback_window: "2_weeks"
  trigger_condition: "2回連続超過"
expected_outcome:
  target_metric: "overdue_ticket_rate"
  target_value: "<= 0.15"
  due_date: "2026-05-15"
resolution_steps:
  - "期限超過チケットを優先順で再計画"
  - "担当者アサインを再調整"
owner: "improvement_detector"
```

> 補足: `lookback_window` は `<数値>_<単位>`（例: `7_days`, `2_weeks`, `1_month`）で統一します。

## 記入例 / Example

```yaml
request_id: "improvement-post-failure-platform-2026w18"
improvement_key: "post_failure_rate_reduction"
service_key: "platform"
meeting_key: "monthly_ops"
status: "monitoring"
signal_summary: "投稿失敗率が3%を超過"
detection_criteria:
  metric: "post_failure_rate"
  operator: ">"
  threshold: 0.03
  lookback_window: "7_days"
  trigger_condition: "週平均で超過"
expected_outcome:
  target_metric: "post_failure_rate"
  target_value: "<= 0.01"
  due_date: "2026-05-31"
resolution_steps:
  - "失敗理由を分類して上位2原因を先に修正"
  - "修正後7日間を再観測"
owner: "ops_quality_owner"
```

## 冪等性メモ / Idempotency Notes

- `request_id` と `improvement_key` をセットで重複判定する
- 同一シグナルの再通知は新規起票せず、同一レコード更新を優先する

## 監査性メモ / Auditability Notes

- 検知時点の観測値（metric value）を必ず残す
- 解消判定時は「いつ」「誰が」「どの基準で」resolvedにしたかを記録する
