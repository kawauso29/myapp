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
| 38 | 人事評価 / 組織再編 | §19 | 大 | ✅ 完了（モデル層 + `Hr::Evaluator`（5 評価軸）+ `HrEvaluationRunJob`（四半期）） |
| 39 | Phase E: 顧客フィードバック導線 | §32.1 / Phase E | 中 | ✅ 完了（`CustomerFeedbackLedger` + `Feedback::Intake`（高重大度は即 escalate）） |
| 40 | LLM 判断への差し替え（`LlmGateway` 統一） | `thu_apr_16` 議題 / §32.1 | 大 | 🔧 `Llm::Gateway` 追加 + `Planner` / `EffectivenessEvaluator` / `Audits::RecordDecision` に augment hook（`LLM_GATEWAY_ENABLED=1` で有効化）。既存ルールベース挙動はデフォルト保持 |
| 41 | ポートフォリオ層の稼働 | §4.2 | 大 | ✅ 完了（モデル層 + `Portfolio::Rebalancer`（service KPI grade ベース分類）+ `PortfolioRebalanceRunJob`（四半期）） |
| 42 | 圧縮時間軸の cron / Runner 統合 | §11 | 中 | ✅ 完了（`Ledgers::TimeAxis::INTERVALS` を正本に cron / Runner / idempotency_key を統一） |
| 43 | 設計ギャップ修正（daily / carry_over / scope_level） | §12.6 / §33.2 / §4 | 中 | ✅ 完了（PR: copilot/check-auto-process）→ 下記「Phase 43 詳細」参照 |
| 44 | 残設計ギャップ（DB化・heartbeat駆動等） | §11.3 / §12 / §19 | 大 | ✅ 完了 → 下記「Phase 44 詳細」参照 |

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
- [x] `TicketLedger.warn_lane_capacity` / `TicketLedger.warn_pr_guardrail` を追加し、production で WIP 超過 / ADR・Runbook 不足を **警告ログ**として記録
- [x] `TicketLedger.enforce_lane_capacity` / `TicketLedger.enforce_pr_guardrail` を追加し、`ENFORCE_LANE_CAPACITY=1` / `ENFORCE_PR_GUARDRAIL=1` で段階的に block モードへ切替可能（`skip_lane_capacity_guard` / `skip_pr_guardrail` で個別 bypass 可能）
- [x] 補強9: `ticket_ledgers.template_id` 列追加 + `CopilotInputTemplate#generate` 時に保存（`tmpl-<ticket_type>-<id>` 形式・unique）
- [x] Phase 38b: `Hr::Evaluator`（5 評価軸: artifact_quality / kpi_contribution / execution_efficiency / collaboration / sustainability）+ `HrEvaluationRunJob`（四半期）
- [x] Phase 41b: `Portfolio::Rebalancer`（service KPI の grade から `invest / rebalance / exit` 候補を PortfolioStrategyLedger に記録）+ `PortfolioRebalanceRunJob`（四半期）
- [x] Phase 40: `Llm::Gateway` 統一入口（feature-flag `LLM_GATEWAY_ENABLED`）+ `Planner` / `EffectivenessEvaluator` / `Audits::RecordDecision` に LLM augment hook（無効時は既存ルールベース挙動をそのまま維持）

## 次 PR に分離

（本 PR で上記をすべて実装済み。残件は本番での enforce モード ON タイミングのみ）

## Phase 42: 圧縮時間軸（4 年 = 28 日）の実装定着

設計書 `thu_apr_16_2026_自律運営型ai企業体の設計.md` §11（line 2309 で確定）の固定値:

| cadence | 圧縮 interval | 実時間軸での意味 |
|---|---|---|
| daily | 30 分 | 1 日相当 |
| weekly | 4 時間 | 1 週相当 |
| monthly | 12 時間 | 1 ヶ月相当 |
| quarterly | 2 日 | 3 ヶ月相当 |
| annual | 7 日 | 1 年相当 |
| long_term | 28 日 | 4 年相当 |

### 何を直したか

- `Ledgers::TimeAxis` 定数モジュールを追加し、6 cadence の固定 interval を一元管理（`INTERVALS` / `interval_for` / `slot_start` / `slot_token` / `due_date_for`）
- `Ledgers::IdempotencyKey.for_meeting` に `cadence:` オプションを追加。指定すると trailing が `Date#iso8601` ではなく `slot_token`（slot 開始時刻）になり、同 slot 内の複数起動だけが冪等弾きされる
- `config/recurring.yml` の Ledger 系 cron を圧縮スケジュールに更新:
  - `weekly_dept_ledger_run`: 週1（毎週月曜）→ **4 時間ごと**
  - `monthly_ops_ledger_run`: 月1（毎月1日）→ **12 時間ごと**
  - `quarterly_review_ledger_run`: 年4（1/4/7/10月）→ **2 日ごと**
  - `annual_plan_ledger_run`: 年1（1/1）→ **7 日ごと（毎週日曜）**
  - `hr_evaluation_run` / `portfolio_rebalance_run`: 年4 → 2 日ごと
- 4 つの Runner（WeeklyDept / MonthlyOps / QuarterlyReview / AnnualPlan）の `idempotency_key` 生成に cadence を渡す
- 4 つの Runner の `due_date` を `Ledgers::TimeAxis.due_date_for(cadence)` に統一（サブ日 cadence は今日 / 今夜のうちの締切）
- `QuarterlyReviewRunner#range_start`: `90.days.ago` → `interval_for(:quarterly).ago`（= 2.days.ago）
- `AnnualPlanRunner#range_start`: `365.days.ago` → `interval_for(:annual).ago`（= 7.days.ago）
- `Ledgers::MasterDataSeeder` の `ServiceHeartbeat#next_run_at` を圧縮 interval 起算に更新

### なぜ重要か

- これまで `quarterly_review` は年4回しか起動せず、1ヶ月（圧縮 4 年）シミュレーション中に 0〜1 回しか発火しなかった → ledger が回らないので、ledger が管理する AI SNS の運営 PDCA も実質的に止まっていた
- 圧縮スケジュールに揃えることで、1ヶ月 = 4 年の運営シミュレーションが期待どおり動く
- DB / コード / cron / spec のあらゆる場所で `Ledgers::TimeAxis::INTERVALS` を **唯一の正本** として参照するため、設計書（§11.3.3）の「DB とコードの乖離防止」方針に整合



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
| 9 Copilot 標準入力テンプレート ID 化 | ✅ | — （`ticket_ledgers.template_id` + `CopilotInputTemplate` 保存） | 35 |

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

## Phase 43 詳細（設計ギャップ修正）

PR: `copilot/check-auto-process` で以下を修正済み。

### 43a: daily cadence Runner 追加（§12.6 選択肢A）
- `meeting_type` enum に `:daily`（8）を MeetingLedger / MeetingDefinition に追加
- `source_meeting_type` enum に `:daily`（6）を TicketLedger に追加
- `Ledgers::DailyRunner` 新規作成 — KPI スナップショット取得・異常検知（critical grade）・hold_items 蓄積
- `DailyLedgerRunJob` — 30分周期 cron（`*/30 * * * *`）
- `MasterDataSeeder` に daily の MeetingDefinition を追加（`chair_role: "system"`）
- `RunnerArtifactPublisher` に `:daily` を追加

### 43b: carry_over_items 全 Runner 適用（§33.2 補強8 完全化）
- `MonthlyOpsRunner` — 前回 weekly_dept の hold_items を carry_over
- `QuarterlyReviewRunner` — 前回 monthly_ops の hold_items を carry_over
- `AnnualPlanRunner` — 前回 quarterly_review の hold_items を carry_over
- チェーン: daily → weekly (hold_items) → monthly (carry weekly) → quarterly (carry monthly) → annual (carry quarterly)

### 43c: scope_level enum 統一（§4 管理階層）
- `CostLedger` / `RolePermission`: `short_term: 3` → `cross_service: 3` に re-label（DB 値変更なし）
- `TicketLedger` / `ComplianceRule`: `cross_service: 3` を追加

### 43d: UiCheck idempotency_key 修正
- `UiCheckLedgerRunJob`: `Date.current.iso8601` → `TimeAxis.slot_token(:quarterly)` に修正

### 43e: その他
- `DailyLedgerRunJob` を `required_job_classes.rb` / `solid_queue.rake` に追加
- No-op migration（schema version bump のみ）: `20260419000001`
- spec: DailyRunner / DailyLedgerRunJob / carry_over_items テスト追加

## Phase 44 詳細（DB 化・heartbeat 駆動・enforce ON）

### 44a: `service_time_axis_settings` テーブル（圧縮時間軸の DB 化）
- `service_time_axis_settings` テーブル作成（`service_id` + `cadence` ユニーク、`interval_seconds` で圧縮率を保持）
- `ServiceTimeAxisSetting` モデル作成（enum cadence、`.interval_for(service_id:, cadence:)` クラスメソッド）
- `Ledgers::TimeAxis.interval_for` に `service_id:` オプション追加。DB に設定があれば優先、なければ `INTERVALS` 定数にフォールバック
- `MasterDataSeeder#seed_time_axis_defaults!` で `ai_sns` サービスのデフォルト値を DB に投入

### 44b: heartbeat `next_run_at` 駆動
- `HeartbeatSchedulerJob` 新規作成 — `ServiceHeartbeat` の `next_run_at <= Time.current` かつ `status: active` を検出し、対応する `ServiceScheduleDefinition` のジョブを起動
- ジョブ実行後に `next_run_at` を次の interval 分だけ進め、`last_run_at` を更新
- `config/recurring.yml` に 5 分毎の `heartbeat_scheduler` エントリ追加
- `required_job_classes.rb` / `solid_queue.rake` に `HeartbeatSchedulerJob` 追加

### 44c: `service_schedule_definitions` + `job_key` 拡張
- `service_schedule_definitions` テーブル作成（`job_key` ユニーク、`job_class` / `cron` / `service_id` / `cadence` / `args` / `enabled`）
- `ServiceScheduleDefinition` モデル作成（`.active` スコープ、`#job_klass` メソッド）
- `MasterDataSeeder#seed_schedule_definitions!` で Ledger 系 8 ジョブを DB に投入
- `HeartbeatSchedulerJob` が `ServiceScheduleDefinition` を参照して動的にジョブを起動

### 44d: 組織ロール定義マスタ
- `organization_roles` テーブル作成（`role_key` ユニーク、`display_name` / `scope_level` / `category` / `active`）
- `OrganizationRole` モデル作成（`.validate_roles(role_keys)` でマスタ検証）
- `MeetingDefinition` に `participant_roles_known` バリデーション追加（マスタデータ存在時のみ検証、後方互換）
- `MasterDataSeeder#seed_organization_roles!` で 12 ロール（executive 6 + department 4 + specialist 2）を投入

### 44e: 本番での enforce ON
- `TicketLedger.enforce_template` class_attribute 追加 + `before_create :assert_template_present!` コールバック
  - `ENFORCE_TEMPLATE=1` で有効化。`skip_template_guard = true` で個別 bypass 可能
- `AuditDecisionLedger.enforce_audit_reason` class_attribute 追加 + `validate :reason_detail_required_when_enforced`
  - `ENFORCE_AUDIT_REASON=1` で有効化。非承認判断（reject/request_changes/abstain）に `reason_detail` を必須化
  - `skip_audit_reason_detail = true` で個別 bypass 可能
- `config/initializers/ticket_stop_guard.rb` に 2 つの ENV トグルを追加

### 切り替え手順

```bash
# Step 1: 警告ログで十分なデータ収集を確認後、VPS .env に追記
echo "ENFORCE_TEMPLATE=1" >> /home/ubuntu/myapp/.env
echo "ENFORCE_AUDIT_REASON=1" >> /home/ubuntu/myapp/.env

# Step 2: Puma 再起動で反映
sudo systemctl restart puma

# Step 3: ロールバック（問題発生時）
# .env から該当行を削除して再起動
```

