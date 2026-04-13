# プロジェクト: GitHub Actions 自前移行

> **このドキュメントはすべてのAIエージェント間で認識を統一するための正規情報源です。**
> 変更が発生したら必ずこのドキュメントも更新してください。

---

## 1. プロジェクト概要

### 目的

サードパーティの GitHub Actions（`appleboy/ssh-action`, `appleboy/scp-action`）を廃止し、
さくらVPS上の **self-hosted runner**（`[self-hosted, sakura-vps]`）でコマンドを直接実行する方式に移行する。

### 移行の理由

| 観点 | 旧方式（appleboy actions） | 新方式（self-hosted runner） |
|------|--------------------------|------------------------------|
| セキュリティ | SSH秘密鍵を GitHub Secrets に預ける必要あり | runner が VPS 上で動作するため SSH 不要 |
| 速度 | SSH接続 + コマンド転送のオーバーヘッドあり | ローカル実行のため高速 |
| 依存 | サードパーティ action のバージョン管理が必要 | 依存なし |
| デバッグ | SSH越しで見づらい | VPS上でログを直接確認可能 |

### セットアップ手順

`.github/docs/self-hosted-runner-setup.md` を参照。

---

## 2. 移行状況

### ✅ 完了（2026-04-12 PR #70 でマージ済み）

| ワークフロー | 移行前 | 移行後 |
|---|---|---|
| `deploy.yml` (deployジョブ) | `ubuntu-latest` + `appleboy/ssh-action` + `appleboy/scp-action` | `[self-hosted, sakura-vps]` + `run:` で直接実行 |
| `db_snapshot.yml` | `ubuntu-latest` + SSH | `[self-hosted, sakura-vps]` + ローカル実行 |
| `weekly_pdca.yml` | 元々 self-hosted | `[self-hosted, sakura-vps]` ✅ |

### ✅ 完了（`db_snapshot.yml` の権限エラー修正済み）

**状況**: `permissions: contents: write` を追加して修正完了。

### ➡️ 移行不要（意図的に ubuntu-latest のまま）

| ワークフロー | 理由 |
|---|---|
| `ci.yml` (全ジョブ) | PostgreSQL/Redis のサービスコンテナを使用。クリーンな環境で実行すべき |
| `deploy.yml` (build_frontendジョブ) | Node.js ビルドのみ。VPSアクセス不要 |
| `auto_fix.yml` | rubocop + PR 作成のみ。VPSアクセス不要 |
| `auto_merge.yml` | GitHub API 操作のみ |
| `auto_create_pr.yml` | GitHub API 操作のみ |
| `pr_ci_fix.yml` | コード修正 + PR 更新のみ |
| `post_deploy_cleanup.yml` | GitHub API 操作のみ |
| `create_pr.yml` | GitHub API 操作のみ |
| `close_session_on_merge.yml` | GitHub API 操作のみ |
| `copilot-setup-steps.yml` | Copilot 環境構築。GitHub ホステッドで実行が正しい |

---

## 3. 稼働確認ログ

| ワークフロー | 最終確認日 | 結果 |
|---|---|---|
| `deploy.yml` | 2026-04-12 | ✅ 直近5回連続成功（workflow_run/workflow_dispatch 両方） |
| `db_snapshot.yml` | 2026-04-12 | ✅ 権限エラー修正済み（`permissions: contents: write`追加） |
| `weekly_pdca.yml` | 未実行 | 次回スケジュールは月曜 9:00 JST |

### ⚠️ self-hosted runner 再登録（2026-04-13）

runner が `sakura-vps` ラベルなしで登録されていたため、以下の手順で再登録済み：

```bash
cd ~/actions-runner && sudo ./svc.sh stop && sudo ./svc.sh uninstall \
  && ./config.sh remove --token <TOKEN> \
  && ./config.sh --url https://github.com/kawauso29/myapp --token <TOKEN> \
    --labels sakura-vps --unattended \
  && sudo ./svc.sh install && sudo ./svc.sh start
```

- **状態**: `Active: active (running)` 確認済み（2026-04-13 12:32 JST）
- **ラベル**: `self-hosted, X64, Linux, sakura-vps`
- **PATH**: rbenv も正しく引き継がれている
- **次のアクション**: `db_snapshot.yml` を手動 dispatch してランナー動作を確認する

---

## 4. アーキテクチャ検討事項

> 以下はオーナーと複数の AI エージェントが議論・合意形成するための検討事項です。
> 結論が出たら「決定事項」セクションに移動してください。

---

### 検討①: Picro送信 / Trading管理機構を別リポに切り出すべきか

#### 現状の構成

```
myapp（Railsモノリス）
├── AI SNS（メイン機能: ai_user, ai_post, ai_relationship 等 20+モデル + 30+ジョブ）
├── Picro通知（PicroCheckJob + PicroScraperService + LineNotifierService）
└── Trading管理（MarketAnalysisJob + Orchestrator + 5エージェント + Mt4Bridge）
```

#### 切り出しの評価

| 観点 | Picro通知 | Trading管理 |
|---|---|---|
| 独立性 | ✅ 完全独立（AI SNS と共有データなし） | ✅ 完全独立（AI SNS と共有データなし） |
| 実装規模 | 小（3ファイル + 1モデル + 1ジョブ） | 中（10+ファイル, 5エージェント） |
| スケーリング要件 | なし（1日数回の定期実行） | なし（15分ごと、市場時間内のみ） |
| デプロイ頻度 | 低い | 低い |
| 外部依存 | LINE API, Picro（スクレイピング） | MT4 EA（HTTP GET） |
| DB共有 | Solid Queue, picro_messages テーブル | TradeDecision, MarketSnapshot 等 |
| 切り出しのコスト | 中（新リポ作成 + 別サーバーor同VPS別プロセス） | 高（5エージェント + Orchestrator + RiskManager を独立させる必要） |

#### 判断基準と推奨

**現時点での推奨: モノリスを維持する**

理由:
1. **運用コスト > メリット**: 2機能とも実行頻度が低く（Picro: 毎日数回, Trading: 15分間隔）、スケーリングの必要がない
2. **Solid Queue の共有が効率的**: 別リポにするとそれぞれに Solid Queue + Redis + PostgreSQL が必要
3. **デプロイの一元管理**: self-hosted runner で1回のデプロイで全機能が更新される
4. **VPS リソースに余裕**: さくらVPS 2GB + 2GB swap で問題なし

**切り出しを検討するタイミング（将来）**:
- Picro や Trading が主要機能として成長し、デプロイ頻度が AI SNS と乖離したとき
- Trading が複数銘柄・複数取引所に拡張して規模が10倍以上になったとき
- チームが分かれて異なる開発者が担当するようになったとき

---

### 検討②: さくらVPS → 無料プラットフォーム（Cloudflare 等）への移行

#### 現在のインフラ構成

| 項目 | 内容 |
|---|---|
| サーバー | さくらVPS 2GB（Ubuntu 22.04） |
| 費用 | 約 880円〜1,980円/月（プランによる） |
| 常駐プロセス | Puma（Rails アプリ） + Solid Queue（30+ジョブ常時待機） |
| DB | PostgreSQL 16 |
| キャッシュ/キュー | Redis + Solid Queue |
| 定期ジョブ | 15分〜毎日（MarketAnalysisJob, AI SNS各種ジョブ等） |
| self-hosted runner | ✅ 稼働中（PR #70 でデプロイに使用） |

#### 無料プラットフォームの評価

| プラットフォーム | Rails 対応 | 常駐プロセス | Solid Queue | 定期ジョブ | 評価 |
|---|---|---|---|---|---|
| **Cloudflare Workers** | ❌ | ❌ | ❌ | ❌ | **不適** |
| **Render（無料枠）** | ✅ | ⚠️ 15分無操作でスリープ | ⚠️ 外部Redis要 | ⚠️ Cron jobのみ | **不適**（スリープ問題） |
| **Railway（無料枠）** | ✅ | ✅ | ⚠️ Redis別途 | ✅ | △（月$5相当の無料枠あり・制限あり） |
| **Fly.io（無料枠）** | ✅ | ✅ | ⚠️ Redis別途 | ✅ | △（256MBメモリ制限が厳しい） |
| **さくらVPS（現状）** | ✅ | ✅ | ✅ | ✅ | ✅ |

#### Cloudflare Workers が不適な理由

Cloudflare Workers は JavaScript/WASM のサーバーレス実行環境であり、以下の要件を満たせない:

- Ruby/Rails は動作しない（V8 isolates のみ）
- 常駐プロセスが存在しない（リクエスト駆動のみ）
- Solid Queue（30+の定期ジョブ）を実行できない
- PostgreSQL に直接接続できない（D1 は SQLite 互換の別DB）
- self-hosted runner のホスト先として使えない

#### 判断基準と推奨

**現時点での推奨: さくらVPS を維持する**

理由:
1. **アプリの性質が無料プラットフォームと相性が悪い**: 30以上の定期ジョブが常時稼働する stateful な Rails アプリに「サーバーレス」は適合しない
2. **self-hosted runner の資産**: PR #70 でデプロイを self-hosted runner に移行完了。VPS を廃止するとこの資産が失われる
3. **コスト感**: さくらVPS 880円/月は安価。無料プラットフォームへの移行工数（数日〜1週間）を考えると費用対効果が低い
4. **「無料」プラットフォームの制限**: スリープ、メモリ制限、Redis 別途、デプロイ上限等の制限が多く、現在の機能を維持できない可能性が高い

**将来の見直しポイント**:
- アプリが大規模化してさくらVPS 2GB では対応できなくなったとき → より高スペックな VPS またはクラウド（AWS/GCP/Azure）を検討
- Picro/Trading を切り出した場合 → 切り出し先の軽量サービスに Cloudflare Workers/Render 等を使うことは可能

---

## 5. 決定事項（合意済み）

| 日付 | 決定内容 | 関連PR/コミット |
|---|---|---|
| 2026-04-12 | deploy.yml / db_snapshot.yml を self-hosted runner に移行 | PR #70 |
| 2026-04-12 | モノリスを維持（Picro/Trading の切り出しは行わない） | このドキュメント |
| 2026-04-12 | `db_snapshot.yml` の `permissions: contents: write` 修正 | このコミット |

---

## 6. 今後のアクション（TODO）

- [x] `db_snapshot.yml` の `permissions: contents: write` 修正（完了）
- [x] self-hosted runner を `sakura-vps` ラベル付きで再登録（2026-04-13）
- [ ] `db_snapshot.yml` を手動 dispatch して runner 動作を確認（再登録後の初回テスト）
- [ ] self-hosted runner のオフライン監視（GitHub Settings → Actions → Runners で定期確認）
- [ ] weekly_pdca.yml の初回実行確認（2026-04-14 月曜 9:00 JST）

---

## 7. 関連ファイル

| ファイル | 役割 |
|---|---|
| `.github/docs/self-hosted-runner-setup.md` | VPS への runner セットアップ手順 |
| `.github/workflows/deploy.yml` | デプロイワークフロー（self-hosted runner） |
| `.github/workflows/db_snapshot.yml` | DB スナップショット（self-hosted runner） |
| `.github/workflows/weekly_pdca.yml` | 週次 PDCA（self-hosted runner） |
| `.github/workflows/ci.yml` | CI（GitHub ホステッドランナー・変更なし） |
