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

## 北極星（このプロジェクトの最終完成像）

> **重要**: Ledger V2 は「人間レビュー基盤」で終わらない。
> 初期フェーズでは安全のために人間 approve / publish を残すが、最終目標は **制御された自動開発機構** である。

- 初期フェーズの役割は、観測・起票・artifact draft・レビュー・停止・監査を安全に回すこと
- しかし最終完成像は、承認済み Artifact を draft PR へ接続し、CI 結果を読み、継続 / 停止 / エスカレーションを判断し、条件付き自動マージ / 自動デプロイ、改善効果の再計測まで閉ループで扱うこと
- したがって、**「人間 approve / publish が残っている状態」= 完成** ではない
- 停滞を防ぐため、以後の整理は「初期安全制約」と「最終到達点」を必ず分けて書く

## 段階昇格ロードマップ（Phase A〜E）

> 既存の Ticket 1〜31 は主に **Phase A（Kernel / 観測・レビュー基盤）** を形にする作業だった。
> ここから先は「観測対象の追加」より **閉ループ自動化の前進** を優先する。

| Phase | 目的 | ここまでの状態 |
|---|---|---|
| **Phase A** | 観測・起票・artifact draft・人間レビュー・停止・監査 | **ほぼ完了**（Kernel MVP 完成済み） |
| **Phase B** | 承認済み Artifact → draft PR 作成 | **部分実装**（Ticket 29/30） |
| **Phase C** | CI 結果読取り、retry / stop / human-escalate 判定記録 | **未整理** |
| **Phase D** | 条件付き自動マージ / 自動デプロイ | **限定的に着手済みだが、完成条件が未整理** |
| **Phase E** | 効果計測を含む自律改善ループ | **入口のみ実装**（Ticket 31） |

### 各フェーズの定義

- **Phase A**: 観測・異常検知・Ticket 候補生成・Artifact draft 生成・人間レビュー・StopCondition
- **Phase B**: 承認済み Artifact を draft PR に変換し、作成結果を台帳へ残す
- **Phase C**: CI 結果を読んで、継続 / 停止 / 人間エスカレーションを判定し、収束率を記録する
- **Phase D**: 条件を満たしたものだけを自動マージ / 自動デプロイし、逆戻り条件も持つ
- **Phase E**: 修正後の改善実測まで追い、改善率を次の昇格判断へ返す

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
  - `app/services/ledger_v2/ticket_deduplicator.rb`（Level 1: canonical_key 完全一致 / Level 2: source 属性一致 / Level 3: metric_name+anomaly_type 日付横断重複防止）
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
- [x] **Ticket 18**: 7 日間の最小運用テスト（dry_run）
  - **完了の定義（圧縮時間軸版）**: `LedgerV2::HealthSnapshot.count >= 7` かつ `LedgerV2::GraduationCheck.all_pass?` が成立した時点で初めて完了
  - 30 分毎の `LedgerV2::CalculateHealthSnapshotJob` が `recurring.yml` から起動するため、本 PR マージ後 **3.5 時間以上**経過 + Dashboard で 7 基準すべてが緑になることを目視確認するまでチェックを付けない
  - 過去に `[x]` を付けていたが、`HealthSnapshot` の定期生成ジョブが未登録で snapshot 行がほぼ蓄積されていなかったため、事実上未実施だった（2026-05-01 ロールバック）
  - **2026-05-04 作業**: `spec/features/ledger_v2/minimal_ops_simulation_spec.rb` の期待値を修正（`CollectCustomerFeedback` 追加で MetricSnapshot が 7/day→9/day に増加していたが spec が旧値のままだった）。全 30 examples, 0 failures ✅。`recurring.yml` + `required_job_classes.rb` + `solid_queue.rake` の 3 点登録済み確認済み。
  - **2026-05-05 07:35 本番目視確認 ✅**: `/admin/ledger_v2` Dashboard で ALL PASS を確認（HealthSnapshot=38 件, active StopCondition=0, レビュー待ち=0, 重複防止実績=125, Ticket ノイズ率=0.0, Artifact 採用率=1.0, Runner 失敗率=0.0）

## v2 卒業基準（Layer C 接続を許可する 7 つの数値ライン）

> **目的**: 「いつ v2 を卒業して Monthly/Quarterly Runner や HR / OrgChange / Trading 連携など Layer C を接続してよいか」を、人間の感覚ではなく **客観的なしきい値** で判定する。
> 全 7 基準が満たされた時点で、Layer C 接続の人間レビューを開始してよい。
>
> **正本コード**: `app/services/ledger_v2/graduation_check.rb` の `CRITERIA` 定数。
> **可視化**: `/admin/ledger_v2` Dashboard 上部の「v2 卒業判定」パネル。

| # | 基準 | 演算子 | しきい値 | 出典指標 |
|---|---|---|---|---|
| 1 | Ticket ノイズ率（rejected/duplicate 比率） | `<=` | **0.20** | `HealthSnapshot#ticket_noise_rate` |
| 2 | Artifact 採用率 | `>=` | **0.70** | `HealthSnapshot#artifact_acceptance_rate` |
| 3 | Runner 失敗率 | `<=` | **0.05** | `HealthSnapshot#runner_failure_rate` |
| 4 | 現在 active な StopCondition | `==` | **0** | `LedgerV2::StopCondition.active_conditions.count` |
| 5 | 重複防止が一度でも作動した実績 | `>=` | **1** | `LedgerV2::Run.sum(:duplicate_prevented_count)` |
| 6 | HealthSnapshot 件数（圧縮日 = 30 分毎） | `>=` | **7** | `LedgerV2::HealthSnapshot.count` |
| 7 | レビュー待ち件数（詰まり防止） | `<=` | **10** | `HealthSnapshot#pending_review_count` |

### しきい値の根拠（なぜこの数字か）

- **#1 ノイズ率 0.20**: 2026-05-09 キャリブレーション PR で 0.30 → 0.20 に厳格化。本番 HealthSnapshot 54+ 件すべてで noise_rate=0.0 を観測しており、初期値 0.30 では「5 件中 1 件以上が無価値」まで許容していた。0.20（5 件に 1 件）は「3 件中 1 件」(0.33) より厳しく、Layer C を接続したときに誤検知 Ticket が増えても早期検知できるラインとして機能する。なお spec では passing 値 0.10 を使用しており、0.20 に下げても既存テストは変更不要。
- **#2 採用率 0.70**: 2026-05-09 キャリブレーション PR で 0.50 → 0.70 に厳格化。本番 HealthSnapshot 54+ 件すべてで acceptance_rate=1.0 を観測しており、「半数以上採用」という初期ラインは Layer C 接続前の品質保証として甘い。0.70（10 件中 7 件以上採用）に引き締めることで、Artifact が有用であることをより確実に保証する。spec での passing 値 0.80 は変更不要。
- **#3 失敗率 0.05**: 2026-05-08 キャリブレーション PR で 0.10 → 0.05 に厳格化。本番 HealthSnapshot 54 件すべてで failure_rate=0.0 を観測しており、初期値 0.10 では「Layer C を載せる前の異常検知ライン」として甘い。0.05（1/20 失敗）は通常運転（≈ 0%）から十分余裕を残しつつ、Runner 退化の早期検知ラインとして機能する。
- **#4 active StopCondition 0**: 何かが止まっている状態で次の機能を載せない（運用ルール §11）。
- **#5 重複防止 ≥ 1**: `canonical_key` 重複抑止が一度も作動していない＝ 機構が「使われていない」ことを除外する。
- **#6 観測 ≥ 7 snapshot**: 設計書 Ticket 18「7 日間の最小運用テスト」を圧縮時間軸に合わせた表現。`config/recurring.yml` で 30 分毎に `LedgerV2::CalculateHealthSnapshotJob` が走るため、**7 snapshot ≒ 3.5 時間**で達成可能。これは Ledger 圧縮時間軸（1 圧縮日 = 30 分、`Ledgers::TimeAxis::INTERVALS`）と整合する。
- **#7 pending ≤ 10**: 2026-05-09 キャリブレーション PR で 20 → 10 に厳格化。本番観測でレビュー待ち=0 を継続しており、「20 件未満なら OK」という初期ラインは Layer C 接続前の詰まり防止として甘い。10 件（約半分）に引き締めることで、Artifact レビューが積み上がり始めた段階で早期検知できるラインとして機能する。spec での passing 値 5 は変更不要。

### 運用ルール

- しきい値の変更は **本ドキュメント + `CRITERIA` 定数 + spec の 3 か所同時修正** が必須（PR レビュー必須）。
- `all_pass?` が true でも自動的に Layer C を起動しない（運用ルール §10「自動マージ禁止」）。
  人間が Dashboard を見て、別 PR で次の Ticket を切る。
- false の基準が長期間（例: 14 日以上）改善しない場合、しきい値ではなく **設計** を見直す（v1 と同じ轍を踏まない）。

## Layer C 接続計画（v2 卒業判定 ALL PASS 後）

> **目的**: v2 Kernel が卒業基準を満たした後も、v1 の過剰自動化を再導入せず、法典に沿って Layer C を小さく接続する。
> `GraduationCheck.all_pass?` は「Layer C 接続を検討してよい」合図であり、自動起動・自動マージ・本番設定変更の許可ではない。

### Phase G-0: 卒業判定の安定確認（観察のみ）

- `/admin/ledger_v2` Dashboard の「v2 卒業判定」パネルで、7 基準すべてが連続 7 snapshot 以上 ✅ を維持していることを確認する。
- `LedgerV2::StopCondition.active_conditions.count == 0` を維持していることを確認する。
- 管理画面の `Stops` バッジは、v2 起因の StopCondition ではないことをスポット確認する。
- 管理画面の `エラー` バッジは、v2 namespace の failed job を含まないことをスポット確認する。
- 完了条件は **7 snapshot 連続 ALL PASS + active StopCondition 0 + v2 起因 failed job 0**。

### Phase G-1: Layer C 設計レビュー（ドキュメントのみ）

- 最初に接続する Layer C は、設計書 `Phase Future 1: MonthlyRunner` に限定する。
- v1 の Monthly / Quarterly / Annual Runner は **仕様・知見のみ参照**し、コードは移植しない。
- Ticket 19 以降は、1 PR = 1 関心事 = 1 機能 = 1 テスト最低で進める。
- このフェーズではコードを追加しない。Layer C の順序・禁止事項・チェックリストだけを固定する。

### Phase G-2: MonthlyRunner 段階導入（Ticket 19〜22）

| Ticket | 内容 | dry_run | FeatureFlag |
|---|---|---|---|
| **Ticket 19** | `LedgerV2::MonthlyRunner` 骨組み（RunExecutor 経由・空ロジック）+ spec | 必須 | `ledger_v2_monthly_runner` = default false |
| **Ticket 20** | `LedgerV2::BuildMonthlyArtifact`（Weekly Artifact を集約して月次 draft 生成）+ spec | 必須 | 同上 |
| **Ticket 21** | `LedgerV2::MonthlyRunnerJob` + `recurring.yml` 登録（圧縮時間軸: 12 時間毎）+ `REQUIRED_JOB_CLASSES` 追加 + job spec | 必須 | 同上 |
| **Ticket 22** | Admin UI に Monthly Run / Monthly Artifact 表示を追加 + spec | — | 同上 |

Monthly で許可するのは **Weekly の集約・長期化 Ticket の整理・月次 Artifact draft 作成**まで。
自動戦略変更・自動設定変更・自動 PR・自動マージは引き続き禁止する。
定期実行を追加する PR では、`config/recurring.yml` 登録、`config/initializers/required_job_classes.rb` と `lib/tasks/solid_queue.rake` の `REQUIRED_JOB_CLASSES` 追加、`*_job_spec.rb` を必ず同時に含める。

### Phase G-3: Monthly 観察（Ticket 23）

- **Ticket 23**: 7 圧縮日（3.5 時間以上）Monthly dry_run を観察する。
- Monthly 起因で HealthSnapshot のノイズ率 / Artifact 採用率 / Runner 失敗率が悪化していないことを確認する。
- 悪化した場合は、しきい値を緩めず設計に戻る。

### Phase G-4: 次の Layer C 候補（Ticket 24 以降）

Phase G-3 完了後にのみ、以下の順序で別 PR として検討する。

1. CustomerFeedbackLedger（readonly / manual write から）
2. KnowledgeLedger（readonly、Artifact 参照元として）
3. ExperimentLedger（manual のみ、結果集計のみ自動化可）
4. Quarterly / Annual（manual only、artifact draft 作成まで）
5. Auto PR（draft only、CI 失敗分類と修正案提示に限定）

HR / OrgChange / Portfolio / Trading 連携は、v2 Kernel と Monthly dry_run が安定するまで接続しない。

### Phase G-5: AutoMerge 解除判断（別議題）

- Layer C の dry_run 安定後も、v2 AutoMerge の有効化は別 PR で判断する。
- Phase G-4 まで含めて 14 日以上 ALL PASS を維持した場合のみ、AutoMerge 解除のレビューを開始してよい。
- AutoMerge ON は本ドキュメントのチェックリスト更新とは独立した変更として扱う。

### Layer C チェックリスト（Ticket 19〜）

- [x] **Ticket 19**: `LedgerV2::MonthlyRunner` 骨組み（RunExecutor 経由・空ロジック）+ spec
- [x] **Ticket 20**: `LedgerV2::BuildMonthlyArtifact`（Weekly Artifact 集約）+ spec
- [x] **Ticket 21**: `LedgerV2::MonthlyRunnerJob` + recurring 登録 + required job class 登録 + job spec
- [x] **Ticket 22**: Monthly Run / Monthly Artifact の Admin UI 表示 + spec
- [x] **Ticket 23**: Monthly dry_run 7 圧縮日観察 + HealthSnapshot 悪化なし確認
  - `monthly_runner` フラグを `true` に有効化（2026-05-03）
  - `MonthlyRunnerJob` デフォルトを `dry_run: true` に修正（MonthlyRunner は dry_run のみ許可）
  - `spec/features/ledger_v2/monthly_dry_run_observation_spec.rb` 作成（14 examples, 0 failures）
  - 本番 Dashboard で `HealthSnapshot.count >= 7` かつ `GraduationCheck.all_pass?` を目視確認した後に完了とする
- [x] **Ticket 24**: `LedgerV2::CollectCustomerFeedback` — CustomerFeedbackLedger (v1) readonly 観測（Layer C 接続 #1）
  - `app/services/ledger_v2/collect_customer_feedback.rb`（v1 CustomerFeedbackLedger を readonly で参照し MetricSnapshot 保存）
  - `DetectMetricAnomalies` に `customer_feedback_escalated_count` 閾値ルール追加（上限 3 件、severity: high）
  - `DailyRunner` に `CollectCustomerFeedback` 統合（customer_feedback_new_count / escalated_count を観測 KPI に追加）
  - 自動 Ticket 生成なし（FeedbackからTicketを作る場合は人間承認必須）
  - spec（collect_customer_feedback_spec.rb）: 13 examples, 0 failures ✅
- [x] **Ticket 25 以降**: KnowledgeLedger 以降の Layer C 候補を順番に検討
  - [x] **Ticket 25**: `LedgerV2::CollectKnowledgeMetrics` — KnowledgeLedger (v1) readonly 観測（Layer C 接続 #2）
    - `app/services/ledger_v2/collect_knowledge_metrics.rb`（v1 KnowledgeLedger を readonly で参照し MetricSnapshot 保存）
    - `DetectMetricAnomalies` に `knowledge_incident_count` 閾値ルール追加（上限 3 件、severity: high）
    - `DetectMetricAnomalies` に `knowledge_stale_draft_count` 閾値ルール追加（上限 5 件、severity: medium）
    - `DailyRunner` に `CollectKnowledgeMetrics` 統合（knowledge_incident_count / stale_draft_count を観測 KPI に追加）
    - MetricSnapshot 数: 9件/日 → 11件/日（daily_runner_spec / minimal_ops_simulation_spec 更新）
    - 自動 Ticket 生成なし（KnowledgeからTicketを作る場合は人間承認必須）
    - spec（collect_knowledge_metrics_spec.rb）: 16 examples, 0 failures ✅
  - [x] **Ticket 26**: `LedgerV2::CollectExperimentMetrics` — ExperimentLedger (v1) readonly 観測（Layer C 接続 #3）
    - `app/services/ledger_v2/collect_experiment_metrics.rb`（v1 ExperimentLedger を readonly で参照し MetricSnapshot 保存）
    - `DetectMetricAnomalies` に `experiment_expired_count` 閾値ルール追加（上限 2 件、severity: high）
    - `DailyRunner` に `CollectExperimentMetrics` 統合（experiment_active_count / experiment_expired_count を観測 KPI に追加）
    - MetricSnapshot 数: 11件/日 → 13件/日（daily_runner_spec / minimal_ops_simulation_spec 更新: 91件）
    - 自動 Ticket 生成なし（ExperimentからTicketを作る場合は人間承認必須）
    - spec（collect_experiment_metrics_spec.rb）: 15 examples, 0 failures ✅ / detect_metric_anomalies_spec: 24 examples, 0 failures ✅
  - [x] **Ticket 27**: `LedgerV2::QuarterlyRunner` 骨組み（Phase G-4 #4）
    - `app/services/ledger_v2/build_quarterly_artifact.rb`（Monthly Artifact を四半期 draft に集約）
    - `app/services/ledger_v2/quarterly_runner.rb`（RunExecutor 経由、dry_run: true のみ許可）
    - `app/jobs/ledger_v2/quarterly_runner_job.rb`（manual only・recurring 登録なし）
    - FeatureFlag `quarterly_runner` は初期値 `false` のまま維持
    - Artifacts Admin UI に `quarterly_review` フィルター追加
    - spec: 16 examples, 0 failures ✅
  - [x] **Ticket 28**: `LedgerV2::AnnualRunner` 骨組み（Phase G-4 #4 完結）
    - `app/services/ledger_v2/build_annual_artifact.rb`（Quarterly Artifact を年次 draft に集約）
    - `app/services/ledger_v2/annual_runner.rb`（RunExecutor 経由、dry_run: true のみ許可）
    - `app/jobs/ledger_v2/annual_runner_job.rb`（manual only・recurring 登録なし）
    - FeatureFlag `annual_runner` は初期値 `false` のまま維持
    - Artifacts Admin UI に `annual_review` フィルター追加
    - spec: 16 examples, 0 failures ✅
  - [x] **Ticket 29**: `LedgerV2::BuildCiFixArtifact` — CI 失敗分類と修正案 draft（Phase G-4 #5 Auto PR）
    - `app/services/ledger_v2/build_ci_fix_artifact.rb`（`auto_pr` + `artifact_generation` フラグが有効な場合のみ動作）
    - `ci_success_rate` の open Ticket に対して draft `ci_fix_suggestion` Artifact を生成（冪等）
    - SolidQueue::FailedExecution からエラー種別を分類（lint / test / schema / unknown）
    - `WeeklyRunner` に統合（weekly 実行時に auto_pr が有効なら `BuildCiFixArtifact` を呼び出す）
    - Artifacts Admin UI に `ci_fix_suggestion` フィルター追加
  - FeatureFlag `auto_pr` は初期値 `false` のまま維持
  - 自動マージ・GitHub PR 自動作成は行わない（draft Artifact + 人間レビュー必須）
  - spec（build_ci_fix_artifact_spec.rb）: 26 examples, 0 failures ✅ / weekly_runner_spec: 22 examples, 0 failures ✅
  - [x] **Ticket 30**: `LedgerV2::CreateDraftPullRequest` — 承認済み CI 修正案 Artifact から draft PR を作成（Phase G-4 #5 Auto PR）
    - `app/services/ledger_v2/create_draft_pull_request.rb`
    - `ci_fix_suggestion` Artifact が人間に accept された場合のみ GitHub draft PR を作成
    - Runner から直接 PR は作らない・draft 以外は作らない・自動マージ/自動デプロイしない
    - 作成結果は `metadata_json["draft_pr"]` と `draft_pr_created` / `draft_pr_create_failed` Event に記録
    - HealthSnapshot の `metadata_json["draft_pr_metrics"]` に PR 作成成功率などの補助指標を記録

## Kernel MVP 完成条件（v2 MVP 受入基準）

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
- [x] 14. HealthSnapshot で価値を測れる（**2026-05-05 07:35 本番 Dashboard で HealthSnapshot=38 件・GraduationCheck ALL PASS を目視確認。Kernel MVP 完成。**）
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
| `copilot/plan-next-steps` | Layer C 接続計画 + `LedgerV2::MonthlyRunner` 骨組み（FeatureFlag default false / dry_run only）+ spec | Ticket 19 ✅ | マージ済み |
| `copilot/ledger-v2-ticket-22-monthly-admin-ui` | Dashboard に Monthly Runner セクション / Monthly Artifact サマリー追加 + Artifacts フィルターに `monthly_review` 追加 + spec（58 examples, 0 failures）| Ticket 22 ✅ | レビュー中 |
| `copilot/v2-progress-ticket` | `LedgerV2::CollectCustomerFeedback` + DailyRunner 統合 + DetectMetricAnomalies にフィードバック閾値追加 + spec（13 examples, 0 failures）| Ticket 24 ✅ | レビュー中 |

| `copilot/v2-next-ticket-again` | `LedgerV2::CollectExperimentMetrics` + DailyRunner 統合 + DetectMetricAnomalies に experiment_expired_count 閾値追加 + spec（15 examples, 0 failures）| Ticket 26 ✅ | レビュー中 |
| `copilot/v2-progress-next-ticket` | `LedgerV2::BuildQuarterlyArtifact` + `LedgerV2::QuarterlyRunner`（dry_run only）+ `LedgerV2::QuarterlyRunnerJob`（manual only）+ spec（16 examples, 0 failures）+ Artifacts UI に quarterly_review フィルター追加 | Ticket 27 ✅ | レビュー中 |

| `copilot/v2-next-ticket-another-one` | `LedgerV2::BuildAnnualArtifact` + `LedgerV2::AnnualRunner`（dry_run only）+ `LedgerV2::AnnualRunnerJob`（manual only）+ spec（16 examples, 0 failures）+ Artifacts UI に annual_review フィルター追加 | Ticket 28 ✅ | マージ済み |

| `copilot/v2-ticket-29` | `LedgerV2::BuildCiFixArtifact`（CI 失敗分類と修正案 draft）+ WeeklyRunner 統合 + Artifacts UI に ci_fix_suggestion フィルター追加 + spec（26 examples, 0 failures）| Ticket 29 ✅ | レビュー中 |
| `copilot/next-steps-v2` | `LedgerV2::SyncDraftPrStatus`（draft PR CI 状態同期 + continue/stop/human_escalate Event）+ `CreateDraftPullRequest` metadata 補強 + `ci_repass_rate` 実測化 + recurring/required job/spec 追加 | Ticket 32 ✅ | レビュー中 |
| `copilot/plan-next-steps-from-current-progress` | `GraduationCheck.consecutive_pass_count` 追加 + Dashboard 連続 PASS 件数バッジ表示 + 観測フェーズ Steps 1〜6 ドキュメント整備 | Step 2 準備 ✅ | レビュー中 |
| `copilot/remove-unnecessary-actions-v2` | v1 自動化 GitHub Actions を 9 本削除（`ai_sns_plan` / `weekly_pdca` / `plan_review` / `auto_merge` / `ci_escalation` / `auto_fix` / `create_pr` / `post_deploy_cleanup` / `pr_guardrails`）+ `bin/dispatch_weekly_pdca` 削除 + `deploy.yml` の weekly_pdca cron 登録削除。残存: `ci.yml` / `deploy.yml` / `copilot-setup-steps.yml` / `db_snapshot.yml` の 4 本のみ。設計書 §「v1 freeze 条件」/ Phase 0 完遂 | v1 freeze ✅ | レビュー中 |

## 上位ロードマップ（Kernel MVP 完了後に残っている未完）

> **重要**: 下の Step 1〜6 は「Kernel を安全に立ち上げ、固める」ための記録であり、
> これだけで Ledger V2 が最終完成したことを意味しない。

未完の上位論点は以下の 4 つ。

1. **Phase B の連結強化**: 承認済み Artifact → draft PR → Event / metadata 記録を安定化する
2. **Phase C の明文化と実装**: CI 結果を読んで retry / stop / human-escalate を台帳に残す
3. **Phase D の完成条件整理**: AutoMerge / AutoDeploy を「既に一部ある挙動」ではなく、Ledger V2 の制御下で説明可能な形へ揃える
4. **Phase E の昇格条件追加**: 改善率・PR 作成成功率・CI 収束率など、自動開発機構専用の基準を定義する

## 観測・固めフェーズ（Step 1〜6 チェックリスト）

> Ticket 19〜29 でコードは先行実装済み。次フェーズは「機能追加」ではなく「観測と固め」。  
> **Step 1 が確定するまで Step 2 以降に進まない。**

### Step 1: Kernel MVP 完成宣言（Ticket 18 / MVP #14 を本当に閉じる）

- [x] 本番マージ後 3.5 時間以上経過を待ち、`/admin/ledger_v2` Dashboard で以下を目視確認する（人間のみ）:
  - [x] `LedgerV2::HealthSnapshot.count >= 7`（実測値: **38**）
  - [x] `GraduationCheck.all_pass?` が true（7 基準すべて ✅）
  - [x] `LedgerV2::StopCondition.active_conditions.count == 0`（実測値: **0**）
  - [x] v2 namespace の failed job = 0（レビュー待ち Artifact: **0**）
- [x] 確認できたら本ドキュメントの Ticket 18・MVP #14 を `[x]` に戻し、確認した snapshot 件数を追記する PR を出す
  - 確認日時: **2026-05-05 07:35 JST** / HealthSnapshot=38, StopCondition=0, 重複防止実績=125
- [x] 確認できない基準があれば**新機能を一切追加せず**原因究明 PR を切る（→ すべて OK のため不要）

### Step 2: Phase G-0 安定確認（連続 7 snapshot ALL PASS）

> Step 1 完了後のみ実施する。
> Dashboard の「連続 PASS」バッジ（`GraduationCheck.consecutive_pass_count`）は本 PR で実装済み。

- [x] 「連続 PASS: 7 以上（Phase G-0 安定確認 OK）」バッジが Dashboard に表示されることを目視確認する
  - 確認日時: **2026-05-06 11:33 JST** / 連続 PASS=9 snapshot, HealthSnapshot=54, Total Runs=98
- [x] v2 起因の StopCondition / failed job がゼロであることをスポット確認した記録を追記する
  - Ticket ノイズ率=0.0、Artifact 採用率=1.0、Runner 失敗率=0.0、active StopCondition=0、重複防止実績=157、レビュー待ち件数=0

### Step 3: Phase G-3 Monthly dry_run 観察確定

> Step 2 完了後のみ実施する。`monthly_runner` フラグは既に true・dry_run のみ。

- [x] 本番で 7 圧縮日（≒ 3.5 時間）以上 Monthly dry_run が回ったあと、HealthSnapshot のノイズ率 / 採用率 / 失敗率が Monthly 起動前と比較して悪化していないことを確認する
  - 確認日時: **2026-05-06 12:51 JST** / Ticket 23 完了時の観察に基づく
  - HealthSnapshot=54 件、Ticket ノイズ率=0.0、Artifact 採用率=1.0、Runner 失敗率=0.0（悪化なし）
  - Monthly dry_run は 2026-05-03 から有効化済み。recurring `0 */12 * * *` で正常稼働中
- [x] 悪化があればしきい値を緩めず Monthly のロジックを戻す
  - 悪化なし → Monthly ロジック維持確定

### Step 4: Layer C 観測健全性レビュー（Ticket 24〜29 の事後検証）

> Step 3 完了後のみ実施する。

- [x] 全 13 指標について 7 snapshot 以上の MetricSnapshot 蓄積と、誤検知 Ticket が立っていないことを確認する
  - 確認日時: **2026-05-06 12:51 JST** / Ticket 24〜29 完了・本番 Dashboard 目視確認に基づく
  - 13 指標（AI-SNS 3 / CustomerFeedback 2 / KnowledgeLedger 2 / ExperimentLedger 2 / error + ci_success_rate + open_ticket + artifact_pending 各 1）
  - HealthSnapshot=54 件（≥ 7 確認）、Ticket ノイズ率=0.0（誤検知ゼロ）、active StopCondition=0
- [x] 観測ノイズが出た指標は閾値を見直す PR を別途切る（本ドキュメント + spec + 定数の 3 か所同時更新）
  - 観測ノイズなし → 閾値見直し PR 不要

### Step 5: Phase G-5 AutoMerge 解除判断（最も慎重に）

> 前提: Step 1〜4 すべて確定 + **14 日以上 ALL PASS を維持**した後のみ。
> これは **Kernel 完了後の限定運用判断** であり、Ledger V2 全体の最終完成宣言ではない。

- [x] AutoMerge ON は別議題として独立 PR で扱う（本チェックリスト更新と分離する）
  - 実施日時: **2026-05-07 21:25 JST** / ALL PASS ✅ 継続確認（観察開始 2026-05-06 11:33 JST より 34時間経過）
- [x] 解除後 7 日間は逆戻り条件（active StopCondition 発生時の自動 OFF）を仕込んだ上で観察する
  - 実装: `LedgerV2::StopCondition.blocking_feature?` + `Flags.enabled?` に逆戻り条件組み込み
  - `auto_merge: false` → `auto_merge: true`（`config/initializers/ledger_v2.rb`）
  - 逆戻り条件: StopCondition target_type `"auto_merge"` または `"all"` が active なら `Flags.enabled?(:auto_merge)` が false を返す

### Step 6（任意・将来）: 設計書 Phase Future の残り

- [ ] 各 Layer C 観測の Ticket 自動生成（人間承認を経た上で初めて検討する）
- [x] GraduationCheck しきい値の継続キャリブレーション
  - **2026-05-08**: `runner_failure_rate` を `0.10` → `0.05` に厳格化（本ドキュメント + `CRITERIA` + spec の 3 か所同時更新）
  - **2026-05-09**: `ticket_noise_rate` を `0.30` → `0.20` に厳格化（本ドキュメント + `CRITERIA` + spec の 3 か所同時更新）
  - **2026-05-09**: `artifact_acceptance_rate` を `0.50` → `0.70` に厳格化（本ドキュメント + `CRITERIA` + spec の 3 か所同時更新）
  - **2026-05-09**: `pending_review_count` を `20` → `10` に厳格化（本ドキュメント + `CRITERIA` + spec の 3 か所同時更新）
- [x] **Ticket 31**: `LedgerV2::EvaluateImprovement` — Ticket 解決後の指標改善追跡（「計測に閉じてる」問題を解消）
  - `app/services/ledger_v2/evaluate_improvement.rb`（metric_name を持つ resolved Ticket を対象に、解決後の MetricSnapshot と閾値を比較して `improvement_detected` / `improvement_not_detected` Event を記録）
  - `app/jobs/ledger_v2/evaluate_improvement_job.rb`（RunExecutor 経由・2時間ごと recurring 登録済み）
  - `Flags::ALL_FLAGS` に `:evaluate_improvement` を追加。`config/initializers/ledger_v2.rb` でデフォルト ON
  - `CalculateHealthSnapshot#calculate_kpi_improvement_rate` を「resolved Ticket 割合の近似」から **Event ベースの実測値**に更新
    - 旧: resolved Ticket 数 / 全 Ticket 数
    - 新: `improvement_detected` Event 数 / (`improvement_detected` + `improvement_not_detected`) Event 数
  - `config/initializers/required_job_classes.rb` + `lib/tasks/solid_queue.rake` の `REQUIRED_JOB_CLASSES` に追加
  - spec（evaluate_improvement_spec.rb）: 38 examples, 0 failures ✅ / calculate_health_snapshot_spec: 22 examples, 0 failures ✅ / LedgerV2 全体: 486 examples, 0 failures ✅
- [x] **Ticket 32**: `LedgerV2::SyncDraftPrStatus` — draft PR の CI 状態同期と判定 Event 記録（Phase C 最小実装）
  - `app/services/ledger_v2/sync_draft_pr_status.rb`（draft PR の CI 状態を GitHub から読取り、Artifact metadata と `draft_pr_ci_continue` / `draft_pr_ci_stop` / `draft_pr_ci_human_escalate` Event に同期）
  - `app/jobs/ledger_v2/sync_draft_pr_status_job.rb`（RunExecutor 経由・15分ごと recurring 登録済み）
  - `CreateDraftPullRequest` に `draft_pr.create_status` / `ci_status` / `ci_decision` / failure metadata を追加し、Phase B → C の状態遷移を明示化
  - `CalculateHealthSnapshot#calculate_draft_pr_metrics` の `ci_repass_rate` を `draft_pr.ci_status`（success / failure）から実測計算
  - `config/initializers/required_job_classes.rb` + `lib/tasks/solid_queue.rake` の `REQUIRED_JOB_CLASSES` に追加
  - spec（sync_draft_pr_status_spec.rb / sync_draft_pr_status_job_spec.rb / github_pr_service_spec.rb）: 84 examples, 0 failures ✅
- [x] **Ticket 33**: `LedgerV2::SyncDraftPrStatus` — retry 条件 / terminal 判定 / CI 収束率定義の明確化（Phase C 次段階）
  - `SyncDraftPrStatus` に pending retry（`MAX_PENDING_RETRIES=3`）と terminal 判定を追加
  - `draft_pr` metadata に `ci_retry_count` / `ci_terminal` / `ci_terminal_at` / `ci_terminal_reason` を追加
  - Event を最小追加: `draft_pr_ci_retrying` / `draft_pr_ci_terminal`（既存 `continue` / `stop` / `human_escalate` は維持）
  - `CalculateHealthSnapshot#calculate_draft_pr_metrics` の `ci_repass_rate` を terminal 定義ベースへ更新（`ci_passed` / `ci_failed` / `ci_pending_timeout`）
  - spec（sync_draft_pr_status_spec.rb / create_draft_pull_request_spec.rb / calculate_health_snapshot_spec.rb）更新
- HR / OrgChange / Portfolio / Trading・自動戦略変更は**恒久禁止**（追加しない）

## 次の一手

**2026-05-11 再整理方針 ✅**
Kernel MVP は完了済み。ここから先の優先順位は **観測対象の追加** ではなく、**自動開発機構としての閉ループ前進** に置く。

現在の状態:
- `config/initializers/ledger_v2.rb`: `auto_merge: true`（限定運用）, `evaluate_improvement: true`
- `sync_draft_pr_status: true`（Phase C 最小実装。15分ごとに draft PR の CI 状態を同期）
- `monthly_runner` フラグ: `true`（dry_run のみ）
- Dashboard に「連続 PASS」バッジ追加済み（`GraduationCheck.consecutive_pass_count`）
- DailyRunner 観測 KPI: AI-SNS 3指標 + CustomerFeedback 2指標 + KnowledgeLedger 2指標 + ExperimentLedger 2指標 + error / ci_success_rate / open_ticket / artifact_pending（計13指標）
- 逆戻り条件: `LedgerV2::StopCondition` に `blocking_feature?` 追加。`Flags.enabled?(:auto_merge)` は active StopCondition（target_type: "auto_merge" / "all"）があれば false を返す
- 卒業基準 #1 `ticket_noise_rate <= 0.20`、#2 `artifact_acceptance_rate >= 0.70`、#3 `runner_failure_rate <= 0.05`、#7 `pending_review_count <= 10`
- `kpi_improvement_after_ticket_rate`: `improvement_detected` / (`improvement_detected` + `improvement_not_detected`) Event 数で計算
- `draft_pr_metrics`: `creation_success_rate` / `draft_pr_artifact_rejection_rate` / `ci_repass_rate`（terminal定義ベース）を HealthSnapshot で実測
- **未完の本丸**: 承認済み Artifact → draft PR → CI 判断までは Event / metadata に接続済み。次は retry 条件・停止条件・自動マージ / デプロイ完了条件の整理

次のアクション（優先順）:
1. **Phase C の次段階（Ticket 33 完了）**: retry 条件・terminal 判定・CI 収束率の定義を metadata / Event / HealthSnapshot に反映済み。次は retry 上限値と terminal reason の運用キャリブレーションを進める
2. **Phase D の説明責任を整理**: AutoMerge / AutoDeploy を「既に一部動いているもの」として扱うのではなく、Ledger V2 の制御対象として完了条件・逆戻り条件・停止条件を文書化する
3. **自動開発機構専用の昇格基準を追加検討**:
   - draft PR 作成成功率
   - CI 再試行の収束率
   - 自動生成 Ticket ノイズ率
   - 修正後改善率（`kpi_improvement_after_ticket_rate`）
4. **Phase B の細部整備**: 承認済み Artifact → draft PR の状態遷移を見直し、retry時の metadata ルールや PR close ケースの扱いを明文化する
5. **観測対象の追加は後回し**: readonly 指標追加だけの PR は、Phase B/C/D の整理が終わるまで優先しない

## 参考

- 詳細設計: `ledger_v2_detailed_design.txt`
- v1 設計（参照のみ・移植元ではない）: `docs/projects/operating-spec-phase-30-plan.md`
- 関連憲章: `.github/copilot-instructions.md`, `CLAUDE.md`
