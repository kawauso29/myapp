# Standard Inputs（運用入力テンプレート）

このディレクトリは、運用作業（PR/Issue/実装依頼）の入力品質を揃えるための標準入力テンプレート群を管理します。

## Phase 8.2 のガードレール

- PR作成時は `.github/PULL_REQUEST_TEMPLATE.md` の必須セクションをすべて記入してください。
- `.github/workflows/pr_guardrails.yml` が `pull_request` イベントでPR本文を検証します。
- 必須セクションが不足、または空欄の場合はCIが失敗し、不足項目がログに表示されます。
