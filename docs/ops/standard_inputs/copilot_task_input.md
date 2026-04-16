# Copilot実装依頼テンプレート / Copilot Task Input Template

Copilot coding agent へ高品質に実装依頼するための標準入力です。

## 必須項目 / Required Fields

```yaml
request_id: "copilot-phase8-1-standard-inputs-2026-04-16"
title: "Phase 8.1: Add standard operational input templates"
what: "docs/ops/standard_inputs に運用入力テンプレートを追加する"
why: "入力形式を統一し、台帳運用の再現性を上げるため"
background:
  - "Phase 0-7 はマージ済み"
  - "DB台帳ファースト運用（meeting_ledgers / ticket_ledgers / improvements）"
acceptance_criteria:
  - "README と4つの入力テンプレートが追加されている"
  - "meeting_key / ticket_type / status など既存用語と整合している"
  - "冪等性と監査性の記述が各テンプレートにある"
constraints:
  - "最小差分で実装"
  - "CI enforcement や GitHub同期は実装しない（Phase 8.2/8.3）"
tests:
  - "ドキュメント内リンク確認"
  - "必要に応じて既存lintを実行"
rollout:
  plan: "docs反映後、次PhaseでCIガードレールへ接続"
  risk: "用語ゆれによる運用ミス"
  mitigation: "READMEで用語マッピングを明示"
```

## 冪等性メモ / Idempotency Notes

- `request_id` はタスク単位で一意にする
- 同一 `request_id` の再依頼は上書き更新として扱い、重複PRを作らない

## 監査性メモ / Auditability Notes

- 最終PR番号、差分ファイル一覧、検証結果を依頼レコードに残す
- 未対応項目（スコープ外）は明示して次フェーズへ引き継ぐ
