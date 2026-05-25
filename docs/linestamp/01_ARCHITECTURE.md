# 01. アーキテクチャ全体図

## 4階層の創作パイプライン

```
┌──────────────────────────────────────────────────────────────┐
│ Layer 1: 企画 (GitHub Copilot Coding Agent + GitHub Actions) │
│   - 週1: 調査(Research)                                       │
│   - 日3: ブランド企画(Brand)                                  │
│   - 日10: シリーズ企画(Pack)                                  │
│   出力: brand_sources/{slug}/**.md を commit/PR              │
└──────────────────────────────────────────────────────────────┘
                          │
                          ▼ Webhook + git pull
┌──────────────────────────────────────────────────────────────┐
│ Layer 2: 同期 + プロンプト合成 (Rails + Sidekiq)              │
│   - rake linestamp:sync で md → DB                            │
│   - DailyOrchestratorJob で未処理のプロンプト合成              │
│   - PromptComposer (md → 最終プロンプト) → DB保存             │
└──────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────────┐
│ Layer 3: 承認 + 画像取得 (管理画面 + 原田さん)                │
│   - Pack 承認(チェックボックス)                              │
│   - プロンプト表示+コピー → 原田さんが Copilot Chat の         │
│     Designer で画像生成                                       │
│   - 緑背景 or 透過済画像を管理画面からアップロード             │
└──────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────────┐
│ Layer 4: 透過処理 (Rails + Sidekiq + mini_magick)             │
│   - ProcessStampImageJob: raw_image → mini_magick → processed │
│   - processed 直接 attach なら処理スキップ                     │
│   - SlackNotifier (完成通知 + 画像投稿)                        │
└──────────────────────────────────────────────────────────────┘
                          │
                          ▼
           LINE申請用 zip ダウンロード(管理画面)
                          │
                          ▼
                    LINE申請(手動)
```

## ファイル配置(myapp 内)

```
myapp/
├── app/
│   ├── models/linestamp/                  ← サブモジュール
│   │   ├── research.rb
│   │   ├── brand.rb
│   │   ├── pack.rb
│   │   ├── stamp.rb
│   │   └── submission.rb
│   ├── services/linestamp/
│   │   ├── prompt_composer.rb
│   │   ├── chroma_key_processor.rb
│   │   ├── brand_sources_syncer.rb
│   │   ├── line_exporter.rb
│   │   ├── slack_notifier.rb
│   │   └── seeders/nemuinu.rb
│   ├── jobs/linestamp/
│   │   ├── daily_orchestrator_job.rb
│   │   ├── compose_brand_prompt_job.rb
│   │   ├── compose_pack_sheet_prompt_job.rb
│   │   ├── compose_stamp_prompts_job.rb
│   │   ├── process_stamp_image_job.rb
│   │   └── sync_brand_sources_job.rb
│   ├── controllers/admin/linestamp/        ← Rails ERB 管理画面
│   │   ├── dashboard_controller.rb
│   │   ├── packs_controller.rb
│   │   └── stamps_controller.rb
│   └── views/admin/linestamp/
│       ├── dashboard/
│       ├── packs/
│       └── stamps/
├── config/
│   ├── routes.rb                          ← /admin/linestamp/ を mount
│   └── schedule.yml                        ← sidekiq-cron に追加
├── db/migrate/
│   └── YYYYMMDDHHMMSS_create_linestamp_*.rb
├── lib/tasks/
│   └── linestamp.rake                     ← sync 等の rake tasks
├── brand_sources/                          ← git管理されたmdソース(repo直下)
│   ├── README.md
│   ├── _templates/
│   └── nemuinu/                           ← Phase 6 で seed
├── docs/linestamp/                         ← 本設計書 + Copilot 用 guide
│   ├── PLANNING_GUIDE.md                  ← Copilot Coding Agent が読む
│   ├── BRAND_FORMAT_SPEC.md
│   └── PAST_INCIDENTS.md
├── .github/
│   ├── workflows/
│   │   ├── linestamp-research.yml          ← 週1
│   │   ├── linestamp-brand-planning.yml    ← 日3
│   │   └── linestamp-pack-planning.yml     ← 日10
│   └── ISSUE_TEMPLATE/
│       ├── linestamp-research.md
│       ├── linestamp-brand-planning.md
│       └── linestamp-pack-planning.md
└── scripts/
    └── linestamp/                          ← ローカル動作確認スクリプト
```

## モジュール命名規約

- **Models**: `Linestamp::Brand`, `Linestamp::Pack`, …
- **Services**: `Linestamp::PromptComposer`, …
- **Jobs**: `Linestamp::DailyOrchestratorJob`, …
- **Controllers**: `Admin::Linestamp::PacksController`
- **テーブル名**: `linestamp_brands`, `linestamp_packs`, …(プレフィックス必須、既存テーブルと衝突回避)
- **Routes**: `/admin/linestamp/...`(管理画面)、`/api/v1/linestamp/...`(必要なら API)

## 既存資産の流用

| 既存 myapp 資産 | LINEスタンプ工房での利用 |
|---|---|
| PG | DBそのまま |
| Redis | Sidekiq キュー |
| Sidekiq + sidekiq-cron | 定時実行 |
| Devise + JWT | 管理画面の認証(adminロール) |
| ActiveStorage | 画像保存 |
| OpenAI/Anthropic API クライアント | (使わない。SD ローカルへ) |
| GitHub Actions CI | 同workflowに planning workflow を追加 |

## 環境変数追加

```bash
# .env (追加分)

# Slack
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...
SLACK_BOT_TOKEN=xoxb-...
SLACK_DEFAULT_CHANNEL=#linestamp-bot

# brand_sources 同期
LINESTAMP_SYNC_TOKEN=...  # GitHub Actions からの webhook 認証
```

**Stable Diffusion 関連 ENV は不要**(自動生成は採用しないため)。

## 主要依存 gem(追加)

```ruby
# Gemfile
gem 'aasm'                # 状態管理
gem 'mini_magick'         # 緑透過 + LINE規格リサイズ(必須)
gem 'image_processing'    # mini_magick の上位ラッパ(オプション)
gem 'slack-ruby-client'   # Slack ファイルアップロード
gem 'kaminari'            # ページネーション
gem 'sidekiq-cron'        # 定時実行(既存にあれば不要)
```

## データの所在

| データ種別 | 所在 | 真実の源 |
|---|---|---|
| 企画 md ソース | git (brand_sources/) | git |
| 状態 (state machine) | PG | PG |
| 生成画像 | ActiveStorage (local fs) | fs |
| 生成パラメータ | PG (jsonb) | PG |
| ログ | Rails ログ + Sidekiq Web UI | Rails |
| 通知履歴 | Slack channel | Slack |

## 設計原則

1. **Rails管理思想**: プロンプト本文は md ソース、Rails は **合成のみ**
2. **状態は DB のみ**: 画像は ActiveStorage、状態判定は DB のステートマシン
3. **画像生成は外部に委ねる**: Copilot Chat の Designer が画像生成、Rails は仕分けと後処理だけ
4. **冪等性**: 各 Job は再実行しても結果が壊れない。状態遷移は AASM ガードで保証
5. **観測可能性**: Sidekiq Web UI + Slack 通知 + DB クエリで状態が見える
