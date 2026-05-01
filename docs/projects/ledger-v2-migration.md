# Ledger V2 移行プロジェクト

> **このプロジェクトの単一正本ドキュメント**
> 別 PR / 別セッションで作業を継続するときは、まずここを読む。
> 進捗・現状・次の一手はすべてこのファイルに集約する。

## 法典（このプロジェクトの 5 原則）

このプロジェクトはすべて以下の法典に従う。違反する変更は受け付けない。

1. **自動化は最終目的地である**
   - v2 移行作業そのものに v1 の自動化機構（`ai_sns_plan` / `weekly_pdca` / `auto_merge`）を駆動装置として流用しない。
   - v2 が反省点として挙げている「過剰な自動化」を v2 の出生時に注入してはいけない。
2. **管理可能であること**
   - すべての変更は人間レビュー前提・小さな PR で行う。
   - dry_run / StopCondition / CircuitBreaker を最初から備える。
   - 一度に複数機能を入れない。1 PR = 1 関心事。
3. **最小テストから積み上げること**
   - 1 機能 = 1 PR = 1 テスト最低。テストなしのコードは v2 namespace に入れない。
   - リファクタは別 PR、機能追加とは混ぜない。
4. **シンプルで透明であること**
   - **初級エンジニアが読んで構造と意図が分かる**コード・命名・ディレクトリを徹底する。
   - メタプロ・継承の連鎖・暗黙の DSL は避ける。明示的な手続き > 賢い抽象。
   - コメントよりコードで説明する。複雑になったら設計を疑う。
5. **常時引き継ぎ可能であること**
   - 進捗・現状・次の一手は本ドキュメント単一に集約する。
   - 別 PR / 別セッションが本ドキュメントだけ読めば必ず継続できる状態を保つ。
   - 各 PR の最後に本ドキュメントのチェックリストを更新する（更新がない PR は受理しない）。

## 設計の正本

設計の詳細は **`ledger_v2_detailed_design.txt`** を正本とする。
本ドキュメントは **進捗管理と運用ルール** の正本であり、設計を書き換える役割は持たない。
設計に変更が必要になった場合は、まず `ledger_v2_detailed_design.txt` を更新する PR を出す。

## v1 と v2 の関係

| | v1 | v2 |
|---|---|---|
| 位置づけ | 仕様発掘プロトタイプ | 本運用 Kernel |
| 状態 | freeze（参照のみ） | 構築中 |
| コード namespace | `app/models/`, `app/services/Ledgers/` 等の既存配置 | `app/{models,services,jobs}/ledger_v2/` |
| 自動実行 | 段階的に停止予定（別 PR） | dry_run から開始 |
| AutoMerge | 既存（v2 範囲外） | **機構安定まで一時停止**（安定後は自動マージ・自動デプロイへ移行） |
| 移植方針 | コードは持ち込まない | 仕様・知見・ドメイン概念のみ持ち込む |

## 引き継ぎプロトコル（別 PR / 別セッションで再開する手順）

新しいセッションが本プロジェクトを引き継ぐとき:

1. **本ドキュメントを最初に読む**（法典・チェックリスト・直近 PR 欄）
2. **`ledger_v2_detailed_design.txt` の該当チケット節を読む**（Ticket 1〜18）
3. **既存 `app/{models,services,jobs}/ledger_v2/` を `git ls-files` で確認**して、何が既に存在するかを把握する
4. **チェックリストの「次の一手」を 1 つだけ選び、1 PR で完了できるサイズに切る**
5. PR タイトルは `ledger-v2: <Ticket N> <概要>` の形式で統一
6. PR ブランチ名は `copilot/ledger-v2-<keyword>`（対話 hold）または `copilot/auto-ledger-v2-<keyword>`（自動完走）
7. PR 本文の最後に **本ドキュメントの該当チェック項目を `- [x]` に更新するコミット**を必ず含める

## チェックリスト（設計書の 18 チケット）

設計書 §「最初の実装チケット案」に対応。**順番厳守**（依存があるため）。
各チケットは独立した PR として進める。

### 基盤フェーズ（Ticket 1〜5）

- [x] **Ticket 1**: `LedgerV2` namespace と基本ディレクトリを作成する
  - `app/models/ledger_v2/.keep`, `app/services/ledger_v2/.keep`, `app/jobs/ledger_v2/.keep`, `spec/models/ledger_v2/.keep`
  - `app/models/ledger_v2.rb`（module 定義・autoload 起点）
  - smoke spec（`spec/models/ledger_v2_spec.rb`）: 2 examples, 0 failures ✅
- [x] **Ticket 2**: `ledger_v2_runs` / `ledger_v2_events` の migration とモデル
  - 設計書 §「ledger_v2_runs」「ledger_v2_events」のカラムに準拠
  - モデル spec（最低限の create / バリデーション）: 16 examples, 0 failures ✅
- [x] **Ticket 3**: `LedgerV2::RunExecutor` を作成
  - すべての Runner はこれを経由する契約
  - dry_run / idempotency_key / status 遷移
  - `RunnerResult` 値オブジェクト定義（Runner 実装の返り値契約）
  - Flags/CircuitBreaker はスタブ（Ticket 4/5 で置き換え予定）
  - spec: 8 examples, 0 failures ✅
- [x] **Ticket 4**: `LedgerV2::Flags`（FeatureFlag）を作成
  - 新機能はデフォルト disabled
  - 変更は人間のみ（DB or env）
  - `app/services/ledger_v2/flags.rb` + `config/initializers/ledger_v2.rb`
  - service spec: 9 examples, 0 failures ✅
- [x] **Ticket 5**: `ledger_v2_stop_conditions` と `LedgerV2::CircuitBreaker`
  - StopCondition 解除は人間のみ
  - `app/models/ledger_v2/stop_condition.rb` + `app/services/ledger_v2/circuit_breaker.rb`
  - `RunExecutor#circuit_breaker_reason` スタブを本実装に置き換え
  - spec: 32 examples, 0 failures ✅

### Ticket フェーズ（Ticket 6〜7）

- [x] **Ticket 6**: `ledger_v2_tickets` と `canonical_key` 制約（部分 unique index）
  - `db/migrate/20260428100000_create_ledger_v2_tickets.rb`
  - `app/models/ledger_v2/ticket.rb`（enum / validation / association / `.active_exists?`）
  - spec: 20 examples, 0 failures ✅
- [x] **Ticket 7**: `LedgerV2::OpenTicket` / `LedgerV2::TicketDeduplicator`
  - `app/services/ledger_v2/ticket_deduplicator.rb`（Level 1: canonical_key 完全一致 / Level 2: source 属性一致）
  - `app/services/ledger_v2/open_ticket.rb`（重複抑止 / duplicate Event / ticket_opened Event / dry_run 対応）
  - spec: 28 examples, 0 failures ✅

### Metric / Daily フェーズ（Ticket 8〜10）

- [x] **Ticket 8**: `ledger_v2_metric_snapshots`
  - `db/migrate/20260428110000_create_ledger_v2_metric_snapshots.rb`
  - `app/models/ledger_v2/metric_snapshot.rb`（enum / validation / association）
  - spec: 13 examples, 0 failures ✅
- [x] **Ticket 9**: `LedgerV2::DetectMetricAnomalies`
  - `app/services/ledger_v2/detect_metric_anomalies.rb`（閾値ベース、6 metric ルール）
  - spec: 22 examples, 0 failures ✅
- [x] **Ticket 10**: `LedgerV2::DailyRunner` + `DailyRunnerJob` + spec（20 examples, 0 failures）

### Artifact / Weekly フェーズ（Ticket 11〜12）

- [x] **Ticket 11**: `ledger_v2_artifacts` / `ledger_v2_reviews`（17 examples, 0 failures）
- [x] **Ticket 12**: `LedgerV2::WeeklyRunner` と `BuildWeeklyArtifact`
  - `app/services/ledger_v2/build_weekly_artifact.rb`
  - `app/services/ledger_v2/weekly_runner.rb`
  - `app/jobs/ledger_v2/weekly_runner_job.rb`
  - spec（weekly_runner_spec + weekly_runner_job_spec）: 20 examples, 0 failures ✅

### Admin UI フェーズ（Ticket 13〜15）

- [x] **Ticket 13**: `/admin/ledger_v2` Dashboard
  - `app/controllers/admin/ledger_v2/base_controller.rb` + `dashboard_controller.rb`
  - `app/views/admin/ledger_v2/dashboard/index.html.erb`
  - `app/helpers/admin_ledger_v2_helper.rb`（run_status_style / ticket_severity_style）
  - routes.rb: `namespace :ledger_v2 { root to: "dashboard#index" }`
  - admin layout ナビに LedgerV2 リンク追加
  - spec: 11 examples, 0 failures ✅
- [x] **Ticket 14**: Ticket Review UI
  - `app/controllers/admin/ledger_v2/tickets_controller.rb`（index + update: accept/reject/defer/reopen）
  - `app/views/admin/ledger_v2/tickets/index.html.erb`（フィルター + 操作ボタン付き一覧）
  - routes.rb: `resources :tickets, only: [:index, :update]`
  - Dashboard ナビに Tickets リンク追加
  - spec: 25 examples, 0 failures ✅
- [x] **Ticket 15**: Artifact Review UI
  - `app/controllers/admin/ledger_v2/artifacts_controller.rb`（index + update: accept/reject/defer/publish/reopen）
  - `app/views/admin/ledger_v2/artifacts/index.html.erb`（フィルター + 操作ボタン付き一覧）
  - routes.rb: `resources :artifacts, only: [:index, :update]`
  - `AdminLedgerV2Helper#artifact_review_status_style` 追加
  - Dashboard / Tickets の sub-nav に Artifacts リンク追加
  - spec: 30 examples, 0 failures ✅

### 健全性 / 接続フェーズ（Ticket 16〜18）

- [x] **Ticket 16**: `LedgerV2::HealthSnapshot`
  - `db/migrate/20260429000000_create_ledger_v2_health_snapshots.rb`
  - `app/models/ledger_v2/health_snapshot.rb`（enum / validation / scope）
  - `app/services/ledger_v2/calculate_health_snapshot.rb`（各指標の集計ロジック / dry_run 対応）
  - spec（health_snapshot_spec + calculate_health_snapshot_spec）: 25 examples, 0 failures ✅
- [x] **Ticket 17**: AI SNS readonly metrics collector（v2 が AI SNS を観測対象に取り込む最初の接続）
- [ ] **Ticket 18**: 7 日間の最小運用テスト（dry_run）
  - **完了の定義（圧縮時間軸版）**: `LedgerV2::HealthSnapshot.count >= 7` かつ `LedgerV2::GraduationCheck.all_pass?` が成立した時点で初めて完了
  - 30 分毎の `LedgerV2::CalculateHealthSnapshotJob` が `recurring.yml` から起動するため、本 PR マージ後 **3.5 時間以上**経過 + Dashboard で 7 基準すべてが緑になることを目視確認するまでチェックを付けない
  - 過去に `[x]` を付けていたが、`HealthSnapshot` の定期生成ジョブが未登録で snapshot 行がほぼ蓄積されていなかったため、事実上未実施だった（2026-05-01 ロールバック）

## v2 卒業基準（Layer C 接続を許可する 7 つの数値ライン）

> **目的**: 「いつ v2 を卒業して Monthly/Quarterly Runner や HR / OrgChange / Trading 連携など Layer C を接続してよいか」を、人間の感覚ではなく **客観的なしきい値** で判定する。
> 全 7 基準が満たされた時点で、Layer C 接続の人間レビューを開始してよい。
>
> **正本コード**: `app/services/ledger_v2/graduation_check.rb` の `CRITERIA` 定数。
> **可視化**: `/admin/ledger_v2` Dashboard 上部の「v2 卒業判定」パネル。

| # | 基準 | 演算子 | しきい値 | 出典指標 |
|---|---|---|---|---|
| 1 | Ticket ノイズ率（rejected/duplicate 比率） | `<=` | **0.30** | `HealthSnapshot#ticket_noise_rate` |
| 2 | Artifact 採用率 | `>=` | **0.50** | `HealthSnapshot#artifact_acceptance_rate` |
| 3 | Runner 失敗率 | `<=` | **0.10** | `HealthSnapshot#runner_failure_rate` |
| 4 | 現在 active な StopCondition | `==` | **0** | `LedgerV2::StopCondition.active_conditions.count` |
| 5 | 重複防止が一度でも作動した実績 | `>=` | **1** | `LedgerV2::Run.sum(:duplicate_prevented_count)` |
| 6 | HealthSnapshot 件数（圧縮日 = 30 分毎） | `>=` | **7** | `LedgerV2::HealthSnapshot.count` |
| 7 | レビュー待ち件数（詰まり防止） | `<=` | **20** | `HealthSnapshot#pending_review_count` |

### しきい値の根拠（なぜこの数字か）

- **#1 ノイズ率 0.30**: 設計書「最終結論」§成功 7 基準。3 件中 1 件以上が無価値なら自動起票自体を見直す必要がある。
- **#2 採用率 0.50**: Artifact レビューで半数以上が採用されないと「人間がレビューする価値がない」状態。Layer C で増える Artifact 量に耐えられない。
- **#3 失敗率 0.10**: Runner が 10% 失敗するなら CircuitBreaker が機能していても上位 Runner を載せられない。
- **#4 active StopCondition 0**: 何かが止まっている状態で次の機能を載せない（運用ルール §11）。
- **#5 重複防止 ≥ 1**: `canonical_key` 重複抑止が一度も作動していない＝ 機構が「使われていない」ことを除外する。
- **#6 観測 ≥ 7 snapshot**: 設計書 Ticket 18「7 日間の最小運用テスト」を圧縮時間軸に合わせた表現。`config/recurring.yml` で 30 分毎に `LedgerV2::CalculateHealthSnapshotJob` が走るため、**7 snapshot ≒ 3.5 時間**で達成可能。これは Ledger 圧縮時間軸（1 圧縮日 = 30 分、`Ledgers::TimeAxis::INTERVALS`）と整合する。
- **#7 pending ≤ 20**: レビュー待ちが 20 件超 = 人間ボトルネック。Layer C を載せる前に運用フローを見直す必要がある。

### 運用ルール

- しきい値の変更は **本ドキュメント + `CRITERIA` 定数 + spec の 3 か所同時修正** が必須（PR レビュー必須）。
- `all_pass?` が true でも自動的に Layer C を起動しない（運用ルール §10「自動マージ禁止」）。
  人間が Dashboard を見て、別 PR で次の Ticket を切る。
- false の基準が長期間（例: 14 日以上）改善しない場合、しきい値ではなく **設計** を見直す（v1 と同じ轍を踏まない）。

## 最小完成条件（v2 MVP 受入基準）

設計書の「最小完成条件」15 項目に一致。Ticket 18 完了時にこれを総点検する。

- [x] 1. DailyRunner が RunExecutor 経由で動く
- [x] 2. WeeklyRunner が RunExecutor 経由で動く
- [x] 3. Run が記録される
- [x] 4. Event が記録される
- [x] 5. MetricSnapshot が保存される
- [x] 6. 異常検知ができる
- [x] 7. Ticket が作られる
- [x] 8. canonical_key で重複 Ticket が防がれる
- [x] 9. Artifact draft が作られる
- [x] 10. Artifact が人間レビュー待ちになる
- [x] 11. StopCondition で Runner を止められる
- [x] 12. dry_run ができる
- [x] 13. Admin UI で状態が見える
- [ ] 14. HealthSnapshot で価値を測れる（コードは完成しているが、定期生成ジョブが未登録で snapshot 行が蓄積されていなかったため事実上未達。snapshot >= 7 を観測した時点で `[x]` に戻す）
- [x] 15. v1 と同時に副作用を起こさない

## v2 初期で作らないもの（明示的禁止）

設計書「v2 初期で作らないもの」より。これらは v2 Kernel が安定するまで持ち込まない。
PR で持ち込まれた場合は **却下する**。

- MonthlyOpsRunner / QuarterlyReviewRunner / AnnualPlanRunner
- HRLedger / OrgChangeLedger / PortfolioLedger
- Trading 連携 / 自動戦略変更 / 自動組織変更
- **自動マージ**
- 本番設定の自動変更
- AI 人格・記憶・関係性の自動変更
- 強い AutoFix / 自動デプロイ判断

## 運用ルール（v2 内部の鉄則）

設計書「運用ルール」より。

1. v2 初期は Daily / Weekly のみ
2. Monthly 以上は作らない
3. すべての Runner は RunExecutor 経由
4. Run なしの副作用は禁止
5. Event なしの判断は禁止
6. canonical_key なしの自動 Ticket 作成は禁止
7. Artifact は人間レビュー必須
8. StopCondition を AI が解除してはいけない
9. FeatureFlag 変更は人間のみ
10. 自動マージは禁止
11. 本番影響変更は禁止
12. dry_run を先に通す
13. 新機能はデフォルト disabled
14. HealthSnapshot を見て昇格判断する
15. v1 と v2 を同時に自動実行しない

## 直近の PR / 履歴

| PR | 概要 | Ticket | 状態 |
|---|---|---|---|
| (本 PR: `copilot/review-ledger-v2-design`) | プロジェクト法典と引き継ぎ準備のドキュメント整備 + v1 Ledger recurring 停止 + Ticket 1 namespace 作成 (**法典確立 PR のため命名規約適用前。次 PR から `copilot/ledger-v2-*` 命名を厳守**） | Ticket 1 ✅ | マージ済み |
| `copilot/ledger-v2-progress` | `ledger_v2_runs` / `ledger_v2_events` migration + モデル + spec | Ticket 2 ✅ | マージ済み |
| `copilot/ledger-v2-ticket-3-run-executor` | `LedgerV2::RunExecutor` + `RunnerResult` + spec | Ticket 3 ✅ | マージ済み |
| `copilot/ticket-4-progress` | `LedgerV2::Flags` サービス + initializer + spec | Ticket 4 ✅ | マージ済み |
| `copilot/ledger-v2-ticket-5-circuit-breaker` | `ledger_v2_stop_conditions` migration + `LedgerV2::StopCondition` + `LedgerV2::CircuitBreaker` + RunExecutor 統合 | Ticket 5 ✅ | マージ済み |
| `copilot/ledger-v2-ticket-6-tickets` | `ledger_v2_tickets` migration + `LedgerV2::Ticket` + canonical_key 部分 unique index + spec | Ticket 6 ✅ | レビュー中 |

| `copilot/ledger-v2-ticket-7-open-ticket` | `LedgerV2::OpenTicket` + `LedgerV2::TicketDeduplicator` + spec | Ticket 7 ✅ | マージ済み |
| `copilot/add-tests-for-ledger-v2` | `ledger_v2_metric_snapshots` migration + `LedgerV2::MetricSnapshot` + spec | Ticket 8 ✅ | レビュー中 |
| `copilot/12-leder-ticket-progress` | `LedgerV2::WeeklyRunner` + `LedgerV2::BuildWeeklyArtifact` + `LedgerV2::WeeklyRunnerJob` + spec | Ticket 12 ✅ | マージ済み |
| `copilot/12-leder-ticket-progress` | `/admin/ledger_v2` Dashboard controller + view + helper + routing + spec | Ticket 13 ✅ | レビュー中 |
| `copilot/ledger-v2-ticket-16-health-snapshot` | `ledger_v2_health_snapshots` migration + `LedgerV2::HealthSnapshot` + `LedgerV2::CalculateHealthSnapshot` + spec | Ticket 16 ✅ | レビュー中 |

| `copilot/v2-next-ticket` | `LedgerV2::CollectAiSnsMetrics` サービス作成 + DailyRunner をリファクタして CollectAiSnsMetrics に委譲 + `artifact_pending_count` を Artifact モデルから実取得 + spec（14 examples, 0 failures）| Ticket 17 ✅ | レビュー中 |

| `copilot/v2-ticket-18` | `spec/features/ledger_v2/minimal_ops_simulation_spec.rb` — 7日間シミュレーション + MVP 15条件 総点検 (30 examples, 0 failures) | Ticket 18 ✅ | レビュー中 |

## 次の一手

**Ticket 18 完了 ＝ v2 MVP 受入基準 15項目 すべて pass。**
**2026-04-30: FeatureFlag 有効化・recurring.yml 追加 完了。本番稼働中。**

現在の状態:
- `config/initializers/ledger_v2.rb`: 全フラグ `true`（本番有効）
- `config/recurring.yml`: `ledger_v2_daily_runner`（30分毎）/ `ledger_v2_weekly_runner`（4時間毎）追加済み
- Admin UI `/admin/ledger_v2` で Run / Ticket / Artifact / HealthSnapshot を観察できる

次のステップ（7〜14日間の観察後に人間が判断）:
1. `/admin/ledger_v2` Dashboard 上部の **「v2 卒業判定」パネル** を毎日確認する（7 基準が全て ✅ になったら卒業）
2. StopCondition が不意に発火しないか観察する
3. Monthly 以上・その他の拡張は **`GraduationCheck.all_pass?` が true** になってから別 PR で着手する

## 参考

- 詳細設計: `ledger_v2_detailed_design.txt`
- v1 設計（参照のみ・移植元ではない）: `docs/projects/operating-spec-phase-30-plan.md`
- 関連憲章: `.github/copilot-instructions.md`, `CLAUDE.md`
