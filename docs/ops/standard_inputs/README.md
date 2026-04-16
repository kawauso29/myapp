# 標準運用入力テンプレート / Standard Operational Input Templates

Governance OS の運用入力（会議実行、起票、改善シグナル、Copilot依頼）を、最小限の共通フォーマットでそろえるためのテンプレート集です。  
Phase 8.1 では **入力の標準化のみ** を扱い、CI強制（Phase 8.2）や GitHub 連携（Phase 8.3）は含みません。

## 目的 / Purpose

- 人間・エージェント双方の入力粒度をそろえる
- `meeting_ledgers` / `ticket_ledgers` / 改善運用の記録を再現可能にする
- DB台帳ファースト（DBを正本）で、入力→台帳更新→監査の流れを安定化する

## 使い方 / How to Use

1. 目的に合うテンプレートを選ぶ
2. Required（必須）を埋める
3. Idempotency（冪等性）と Auditability（監査性）を必ず記録する
4. 実行後に実績値（ledger id / 実行時刻 / 判断理由）を追記する

## テンプレート一覧 / Templates

- [meeting_input.md](./meeting_input.md): 会議実行・会議記録の入力
- [ticket_input.md](./ticket_input.md): 会議決定を `ticket_ledger` に反映する入力
- [improvement_input.md](./improvement_input.md): 改善シグナル定義・検知条件・解消手順の入力
- [copilot_task_input.md](./copilot_task_input.md): Copilot Coding 依頼の入力

## 用語メモ / Terminology Notes

- `meeting_key`, `ticket_type`, `status` は既存台帳の主要フィールド名に準拠
- `service_key` は運用上の識別キーとして使い、DBの `service_id` に対応づける

## Phase 8.2 のガードレール / Enforcement

- PR作成時は `.github/PULL_REQUEST_TEMPLATE.md` の必須セクションをすべて記入してください。
- `.github/workflows/pr_body_check.yml` が `pull_request` イベントでPR本文を検証します。
- `.github/workflows/pr_guardrails.yml` でも見出し不足・空欄を検証し、不足項目をCIログに表示します。
- 必須セクションが不足、または空欄の場合はCIが失敗します。
