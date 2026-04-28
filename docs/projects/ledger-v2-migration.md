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
- [ ] **Ticket 4**: `LedgerV2::Flags`（FeatureFlag）を作成
  - 新機能はデフォルト disabled
  - 変更は人間のみ（DB or env）
- [ ] **Ticket 5**: `ledger_v2_stop_conditions` と `LedgerV2::CircuitBreaker`
  - StopCondition 解除は人間のみ

### Ticket フェーズ（Ticket 6〜7）

- [ ] **Ticket 6**: `ledger_v2_tickets` と `canonical_key` 制約（部分 unique index）
- [ ] **Ticket 7**: `LedgerV2::OpenTicket` / `LedgerV2::TicketDeduplicator`

### Metric / Daily フェーズ（Ticket 8〜10）

- [ ] **Ticket 8**: `ledger_v2_metric_snapshots`
- [ ] **Ticket 9**: `LedgerV2::DetectMetricAnomalies`
- [ ] **Ticket 10**: `LedgerV2::DailyRunner`（dry_run 対応）

### Artifact / Weekly フェーズ（Ticket 11〜12）

- [ ] **Ticket 11**: `ledger_v2_artifacts` / `ledger_v2_reviews`
- [ ] **Ticket 12**: `LedgerV2::WeeklyRunner` と `BuildWeeklyArtifact`

### Admin UI フェーズ（Ticket 13〜15）

- [ ] **Ticket 13**: `/admin/ledger_v2` Dashboard
- [ ] **Ticket 14**: Ticket Review UI
- [ ] **Ticket 15**: Artifact Review UI

### 健全性 / 接続フェーズ（Ticket 16〜18）

- [ ] **Ticket 16**: `LedgerV2::HealthSnapshot`
- [ ] **Ticket 17**: AI SNS readonly metrics collector（v2 が AI SNS を観測対象に取り込む最初の接続）
- [ ] **Ticket 18**: 7 日間の最小運用テスト（dry_run）

## 最小完成条件（v2 MVP 受入基準）

設計書の「最小完成条件」15 項目に一致。Ticket 18 完了時にこれを総点検する。

- [ ] 1. DailyRunner が RunExecutor 経由で動く
- [ ] 2. WeeklyRunner が RunExecutor 経由で動く
- [ ] 3. Run が記録される
- [ ] 4. Event が記録される
- [ ] 5. MetricSnapshot が保存される
- [ ] 6. 異常検知ができる
- [ ] 7. Ticket が作られる
- [ ] 8. canonical_key で重複 Ticket が防がれる
- [ ] 9. Artifact draft が作られる
- [ ] 10. Artifact が人間レビュー待ちになる
- [ ] 11. StopCondition で Runner を止められる
- [ ] 12. dry_run ができる
- [ ] 13. Admin UI で状態が見える
- [ ] 14. HealthSnapshot で価値を測れる
- [ ] 15. v1 と同時に副作用を起こさない

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
| `copilot/ledger-v2-ticket-3-run-executor` | `LedgerV2::RunExecutor` + `RunnerResult` + spec | Ticket 3 ✅ | マージ済み |

> 新しい PR が起きたら、ここに 1 行追記する。

## 次の一手

1. **本 PR をマージする**（Ticket 3 完了）
2. 次のセッションで **Ticket 4**（`LedgerV2::Flags` 作成）に着手する
   - ブランチ: `copilot/ledger-v2-ticket-4-flags`
   - FeatureFlag: 新機能はデフォルト disabled、変更は人間のみ

## 参考

- 詳細設計: `ledger_v2_detailed_design.txt`
- v1 設計（参照のみ・移植元ではない）: `docs/projects/operating-spec-phase-30-plan.md`
- 関連憲章: `.github/copilot-instructions.md`, `CLAUDE.md`
