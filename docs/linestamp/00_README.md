# LINEスタンプ工房 設計書一式

myapp リポジトリに **`Linestamp::` 名前空間のサブシステム** として組み込む。
本ドキュメント群は GitHub Copilot Coding Agent が実装できる粒度で書かれている。

## 配置先

`myapp/docs/linestamp/` 配下にコピー。

## 読む順番(Copilot 向け)

1. **`01_ARCHITECTURE.md`** — 全体像と決定事項。最初に読む
2. **`02_DB_SCHEMA.md`** — マイグレーション仕様
3. **`03_MODELS.md`** — モデル + AASM
4. **`04_SERVICES.md`** — サービス層(PromptComposer / SD / mini_magick / Slack)
5. **`05_JOBS.md`** — Sidekiq ジョブ
6. **`06_ADMIN_UI.md`** — Rails 管理画面(Pack 承認チェックボックス)
7. **`07_GITHUB_WORKFLOWS.md`** — GitHub Actions(企画レイヤー)
8. **`08_PLANNING_GUIDE.md`** ★ — Copilot Coding Agent の "skill" 本体
9. **`09_BRAND_FORMAT_SPEC.md`** — mdファイル仕様
10. **`10_PAST_INCIDENTS.md`** — ねむ犬から継承する事故と対策
11. **`11_ISSUES_BACKLOG.md`** — フェーズ分割版 Issue 一覧(参考)
12. **`12_REVIEW_AND_GAPS.md`** ★ — セルフレビュー結果と補強事項(実装時必読)
13. ~~`13_SD_SETUP.md`~~ — **削除済**(SD ルートは採用しない)
14. **`14_SINGLE_ISSUE.md`** ★ — **一括実装用 Issue 本文(これを採用)**
15. **`15_MANUAL_ROUTE_FALLBACK.md`** ★ — **唯一の本番ルート**(Designer + 管理画面 + mini_magick)

## 実装フェーズ

```
Phase 1: 基盤      (Issue #1-5)    DB, モデル, AASM
Phase 2: 企画レイヤー (Issue #6-9)  brand_sources, GitHub Actions, PLANNING_GUIDE
Phase 3: 生成レイヤー (Issue #10-15) SD, mini_magick, ジョブ, Slack
Phase 4: 管理画面   (Issue #16-19)  Pack 承認 UI, ダッシュボード
Phase 5: 連動E2E   (Issue #20-22)  webhook, sync, daily orchestrator
Phase 6: ねむ犬移行 (Issue #23-25)  seed, 既存資産取り込み, ドライラン
```

## ねむ犬資産の引き継ぎ

| 既存資産 | 移植先 |
|---|---|
| `01_brand_theme.md` 等のmdソース | `brand_sources/nemuinu/` に配置(Phase 6 で seed) |
| グリーンバック緑透過の仕様 | `Linestamp::ChromaKeyProcessor` (`04_SERVICES.md`) |
| pack_001 の 8枚 manifest | `brand_sources/nemuinu/packs/pack_001/manifest.yml` |
| 過去の事故と対策 | `10_PAST_INCIDENTS.md` |

## 想定スループット

- 調査: 週1
- ブランド企画: 日3
- シリーズ(Pack)企画: 日10(うち承認3)
- LINE申請: 日3 Pack = 24 stamps
- SD 生成: 約 37枚/日 = GPU 19分/日

## 採用決定事項

| 項目 | 決定 |
|---|---|
| Pack 承認 UI | Rails 管理画面のチェックボックス |
| 品質ゲート | 最初は全採用、reject は手動 |
| Brand × Pack | 1 Brand : N Pack(キャラ使い回し) |
| 通知 | Slack Incoming Webhook |
| 透過処理 | mini_magick(Rails内) |
| 画像生成 | **Copilot Chat の Designer(原田さんが手動操作)** |
| 画像受け渡し | **管理画面アップロード(緑背景 or 透過済を選択可)** |
| 企画 | GitHub Copilot Coding Agent(自動) |
| 実行環境 | ローカルマシン1台 |
| **不採用** | Stable Diffusion 自動生成、AUTOMATIC1111 |
