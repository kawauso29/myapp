# 運営 OS: Phase 30〜41 実装計画

## 目的

初期 3 設計文書（`自律開発エージェント設計.md` / `thu_apr_16_2026_自律運営型ai企業体の設計.md` / `ai_enterprise_operating_spec_v1.md`）を正本 (`ai_enterprise_operating_spec_v1.md`) に合流させ、そこで検出された残ギャップを **Phase 30〜41 の通し番号**で閉じる。

これまで並走していた Phase 0〜7（履歴）/ Phase 20〜26（補強10〜16）/ Phase A〜E（自律成長ループ）を統合し、以降の改修は **必ずこの通し番号で起票** する。

## 現状サマリ

| 区分 | 範囲 | 状態 |
|---|---|---|
| Phase 0〜7 | 台帳基盤 + GitHub 運用（PR #190〜#202） | ✅ 完了 |
| Phase 20〜26 | 補強10〜16（サービス層 + 台帳カラム） | ✅ 完了 |
| Phase A〜D | 自律成長ループ（KpiAutoCollector / Planner / TicketIssueSync / EffectivenessRecalc） | ✅ 完了 |
| Phase E | 顧客フィードバック導線 | ❌ 未着手 → Phase 39 |

## Phase 30〜41 一覧

| Phase | 名称 | 根拠 | 粒度 | 状態 |
|---|---|---|---|---|
| 30 | 台帳土台の完成 | §23 / §26 / 補強1・2・3・8 | 中 | ✅ 完了（30a + 30b + 30c） |
| 31 | 成果物 6 台帳の実体化 | §16 / §28 / 補強4 | 大 | ✅ 完了（モデル層 + 31b Admin Viewer + 31c Runner 自動 publish） |
| 32 | `audit_decisions` 台帳 + reason_code 必須化 | §18 / §27 / 補強6 | 中 | ✅ 完了（`AuditDecisionLedger` + `Audits::RecordDecision` + reason_code 強制 + Admin Viewer） |
| 33 | `stop_ledger` + 自動停止トリガー監視ジョブ | §18 / 補強7 | 大 | ✅ 完了（`StopLedger` + `Stops::ConditionEvaluator` + `StopConditionMonitorJob` + `Stops::EntryGuard`（TicketLedger 起票ブロック）+ Admin Viewer（lift 操作付き）） |
| 34 | KPI 段階化（healthy / warning / critical） | §24 / 補強5 | 小 | ✅ 完了 |
| 35 | 起票カテゴリ 11 種完備 | §17 / §27 | 中 | ✅ 完了（`TicketLedger.ticket_type` enum に §17 の 11 種を実装） |
| 36 | 28日運営レーン（4 レーン + 容量制御） | §13 | 中 | ✅ 完了（`operating_lane` + `LaneCapacityCap` + `Ledgers::LaneCapacityGuard` + 警告ログ自動実行） |
| 37 | 知識台帳 + PR ガードレール | §20 | 中 | ✅ 完了（`KnowledgeLedger` + `Knowledge::PrGuardrail` + 警告ログ自動実行 + Admin Viewer） |
| 38 | 人事評価 / 組織再編 | §19 | 大 | 🔧 モデル層完了（`HrEvaluationLedger` / `OrgChangeLedger`）。評価ロジックは 38b で別 PR |
| 39 | Phase E: 顧客フィードバック導線 | §32.1 / Phase E | 中 | ✅ 完了（`CustomerFeedbackLedger` + `Feedback::Intake`（高重大度は即 escalate）） |
| 40 | LLM 判断への差し替え（`LlmGateway` 統一） | `thu_apr_16` 議題 / §32.1 | 大 | ❌ 未着手（影響範囲が広いため別 PR に分離） |
| 41 | ポートフォリオ層の稼働 | §4.2 | 大 | 🔧 モデル層完了（`PortfolioStrategyLedger`）。実運用フローは 41b で別 PR |

## 依存関係

- **Phase 30 / 34 は他の前提**: 他 Phase の作業前にまず完了させる
- **Phase 32〜37 は Phase 31 に依存**: 成果物台帳（Phase 31）ができて初めて「成果物を伴う判断」が参照できる
- **Phase 38 / 40 / 41 は独立・大型**: 個別セッションで進める

## Phase 30 の工程

### Phase 30a（本 PR で完了）

- [x] 補強1: `meeting_ledgers.idempotency_key` 列 + 部分ユニーク index
- [x] 補強1: `ticket_ledgers.idempotency_key` 列 + 部分ユニーク index
- [x] 補強8: `meeting_ledgers.carry_over_items` jsonb 列
- [x] モデルの uniqueness バリデーション（allow_nil: true）
- [x] モデル spec の追加
- [x] 仕様書（§16 / §19 / §20 の実装状況節、§32 の Phase 30〜41 表、§33.2 の補強ステータス）

### Phase 30b（本 PR で追加）

- [x] 補強2: `Ledgers::PreflightValidator` を追加し、Runner が会議を開く前に参加ロール充足を検証（`role_fill_rate` 自動算出、不足時は `PreflightFailure` を raise）
- [x] Runner 側で `idempotency_key` を自動採番（`Ledgers::IdempotencyKey.for_meeting`）
- [x] 4 つの Runner（WeeklyDept / MonthlyOps / QuarterlyReview / AnnualPlan）が `participants` / `role_fill_rate` / `idempotency_key` を必ず記録
- [x] `WeeklyDeptRunner` が `hold_items` を `carry_over_items` にも書き込む（§26.5 / 補強8 の完全化）
- [x] PreflightValidator / IdempotencyKey の RSpec、WeeklyDeptRunner の idempotency / role_fill_rate / carry_over_items テストを追加

### Phase 30c（本 PR で完了）

- [x] 補強3: `Ledgers::SystemMeetingProvider` で月次システム会議を自動発行し、`Reinforcements::Planner` / `Ledgers::ImprovementDetector` が `source_meeting` を必須設定する
- [x] 既存 NULL レコードを「legacy_backfill」meeting に紐付ける backfill migration 実装（`20260417031000_backfill_and_require_source_meeting_id_on_ticket_ledgers.rb`）
- [x] `ticket_ledgers.source_meeting_id` を NOT NULL 化し、`TicketLedger#source_meeting` を `belongs_to`（optional なし）に変更
- [x] `Ledgers::JobIdempotency` concern を追加し、Rails.cache (SolidCache) ベースの 1日冪等性ラッパを提供
- [x] 4 つの ledger runner ジョブ（WeeklyDept / MonthlyOps / QuarterlyReview / AnnualPlan）に適用
- [x] `ticket_ledger` factory をデフォルトで共有 `factory_default_meeting` に紐付ける
- [x] RSpec（JobIdempotency / 既存 ledger spec）を更新

### Phase 31c（本 PR で完了）

- [x] `Ledgers::RunnerArtifactPublisher` を追加（会議の議事要約を `ArtifactLedger` に `execution_plan` として記録）
- [x] 4 つの Runner（WeeklyDept / MonthlyOps / QuarterlyReview / AnnualPlan）から自動 publish
- [x] `meeting.idempotency_key` から派生した `artifact:<runner>:<meeting_key>` を `idempotency_key` に設定して二重記録防止
- [x] RSpec（`spec/services/ledgers/runner_artifact_publisher_spec.rb`）を追加

### Admin Ops UI 3 画面（本 PR で完了）

- [x] `/admin/ops/audit_decisions` — Phase 32 / §18 の決定分布と non-approval 強調
- [x] `/admin/ops/stops` — Phase 33 の停止台帳 + 管理者による **手動 lift アクション**（`lift_reason` 必須）
- [x] `/admin/ops/knowledge` — Phase 37 / §20 の ADR / Runbook / Incident / Deploy 記録
- [x] Admin ナビに 3 リンクを追加、routes に 3 コントローラーを追加
- [x] RSpec（`spec/requests/admin/ops/*_spec.rb` を 3 本追加）

### App 統合 D（本 PR で完了）

- [x] `Stops::EntryGuard` を追加し、active `StopLedger` がある scope への `TicketLedger` 起票をブロック（scope 上位包含あり。company → portfolio → service / cross_service）
- [x] `TicketLedger.enforce_stop_guard` class attribute + `before_create` コールバック + production 初期化子 `config/initializers/ticket_stop_guard.rb` で ON（test は後方互換で OFF）
- [x] 例外経路として `ticket.skip_stop_guard = true` を許可
- [x] **stop_guard bypass ホワイトリスト** `TicketLedger::STOP_GUARD_BYPASS_TICKET_TYPES`: `investigation` / `audit` / `quarterly_review` / `annual_plan` / `service_shutdown` は active stop 中でも記録できる（§18 の趣旨「通常業務の新規起票を止める」に準拠）
- [x] `TicketLedger.warn_lane_capacity` / `TicketLedger.warn_pr_guardrail` を追加し、production で WIP 超過 / ADR・Runbook 不足を **警告ログ**として記録（enforce モードは別 PR で判断）

## 次 PR に分離

- **Phase 40**: `LlmGateway` 差し替え（40a-e 全体）。Planner / EffectivenessEvaluator / Audits の書き換えを伴う
- **Phase 38b**: `Hr::Evaluator` ＋ quarterly recurring job
- **Phase 41b**: `Portfolio::Rebalancer` ＋ quarterly runner
- LaneCapacityGuard / PrGuardrail の **enforce モード**: 警告ログで十分な件数集まってから


## 検出したギャップの詳細（参考）

### A. 補強 1〜9 の実装状況

| No. | 実体 | 足りないもの | Phase |
|---|---|---|---|
| 1 idempotency_key | ✅ | — （台帳 + ジョブ双方に適用済） | 30a / 30b / 30c |
| 2 参加ロール充足 | ✅ | — （Runner プリフライト実装済み） | 30b |
| 3 source_*_id NOT NULL | ✅ | — （backfill + NOT NULL + SystemMeetingProvider） | 30c |
| 4 artifact_version | ✅ | — （ArtifactLedger + Publisher + Runner 自動 publish） | 31 / 31b / 31c |
| 5 KPI grade | ✅ | — （grade enum + thresholds + KpiGradeEvaluator） | 34 |
| 6 audit_decision.reason_code | ✅ | — （台帳 + reason_code 強制 + Admin Viewer） | 32 |
| 7 stop_ledger | ✅ | — （台帳 + ConditionEvaluator + EntryGuard + Admin Viewer） | 33 |
| 8 carry_over_items | ✅ | — （WeeklyDept 書き込み済み） | 30a / 30b |
| 9 Copilot 標準入力テンプレート ID 化 | △ | `template_id` 列 | 35 |

### B. §16 成果物の実体化（Phase 31）

`artifact_ledger` / `artifact_versions` が無い。KPI 定義書・仕様書・実行計画書・監査判定書・顧客案内・技術記録の 6 成果物はテンプレート文字列のみ存在する。§28 テンプレートと補強4（artifact_version）と一体で作る。

### C. §18 監査・停止条件の自動化（Phase 33）

- `stop_ledger`（軽度/部分/全社停止）未実装
- 停止トリガー自動検知（コスト急増 / クレーム急増 / エージェント暴走 / 調整不能な部門衝突）の監視ジョブ無し
- `Reinforcements::KillSwitchGuard` は `operator_override_ledger` の手動停止だけを見ている

### D. §19 人事評価 / 組織再編（Phase 38）

- `hr_evaluation_ledger` / `org_change_ledger` 無し
- 評価軸 5 項目（成果品質・KPI 貢献・実行効率・協調性・継続可能性）の自動計測無し
- プロンプト修正 / 配置変更提案 / 分割統合提案の経路無し

### E. §20 知識管理（Phase 37）

- ADR / Runbook / 障害知見 / デプロイ記録の台帳化無し
- 「デプロイ前更新完了確認」の機械化は PR テンプレチェックのみで、本文欄未記入でブロックする仕組み無し

### F. §17 起票カテゴリ（Phase 35）

現 `ticket_type` enum: `operations / audit / ops / quarterly_review / annual_plan / improvement / service_shutdown / service_pivot`（8 種）

仕様 §17 は 11 種: 施策 / 調査 / 監査 / 人事 / 顧客案内 / 技術記録 / 組織 / 経営 / 新規サービス / サービス縮小・廃止 / サービス統合

未実装: 施策 / 調査 / 人事 / 顧客案内 / 技術記録 / 組織 / 経営 / 新規サービス / サービス統合（9 種）

### G. §13 28日運営レーン（Phase 36）

即時対応 / 四半期運営 / 年次経営 / 長期経営の 4 レーンが「ラベル」としても存在しない。現状は recurring cron に畳まれていてレーン単位の容量制御・優先度制御が無い。

### H. Phase E 顧客フィードバック導線（Phase 39）

AI SNS 側の UI（離脱理由 / 不満ポイント / NPS 的指標）→ KPI 還流が未接続。

### I. LLM 統合（Phase 40）

`thu_apr_16_2026` 側で議題化された Gemini 統合ドラフトが未着手。現状 `LlmClient` / `LlmBudgetTracker` は存在するが、`Planner` / `ConflictResolver` / `EffectivenessEvaluator` が全部ルールベースで、LLM 判断に差し替わっていない。

### J. ポートフォリオ層（Phase 41）

`business_unit_id` / `service_group` / `cross_service_flag` カラムはあるが、ポートフォリオレベルの会議・判断が機械化されていない。§4.2 事業ポートフォリオレイヤーが実質未稼働。

## 進め方の原則

1. **Phase 30a / 30b / 30c / 34 は差分小さめ**: 早期に入れて他 Phase の前提にする
2. **Phase 31 が最大の構造ギャップ**: 成果物台帳ができれば §16 と §28 がコード上で完結する
3. **Phase 32〜37 は Phase 31 完了後に着手**
4. **Phase 38 / 40 / 41 は独立・大型**: 別セッションで順次
5. **1 PR = 1 Phase の小単位** が望ましい（レビュー可能性優先）
