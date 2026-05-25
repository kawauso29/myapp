# 15. Manual Route(画像生成・透過の唯一ルート)

> **このプロジェクトでは Stable Diffusion 自動生成ルートは採用しない。**
> 画像生成は **原田さんが Copilot Chat の Designer で生成** し、
> **管理画面からアップロード** することで Rails に取り込む。
> 透過処理は mini_magick で自動、または既に透過済み画像なら直接受け入れる。

これは「フォールバック」ではなく **唯一の本番ルート**。

---

## 採用する流れ(全体)

```
[Copilot Coding Agent] 企画 → brand_sources/*.md → PR → マージ
       ↓ (rake linestamp:sync)
[Rails] Brand / Pack / Stamp レコード作成
       ↓ (DailyOrchestratorJob)
[Rails] プロンプト合成 → DB(brand.base_prompt / pack.sheet_prompt / stamp.prompt)
       ↓
[管理画面] プロンプトを表示 + コピーボタン
       ↓
[原田さん] プロンプトをコピー → Copilot Chat の Designer で画像生成 → ローカル DL
       ↓
[管理画面] 緑背景画像をアップロード(または既に透過済みなら直接アップ)
       ↓ (緑背景の場合は ProcessStampImageJob 自動起動)
[Rails] mini_magick で透過 → LINE規格(370×320)で processed_image attach
       ↓
[管理画面] export_for_line で LINE申請用 zip ダウンロード
       ↓
[原田さん] LINE 申請(手動)
```

---

## 削除した要素(SD 関連は全て不採用)

| 要素 | 状態 |
|---|---|
| `Linestamp::StableDiffusionClient` | ❌ 削除 |
| `GenerateBrandBaseImageJob` | ❌ 削除 |
| `GeneratePackSheetImageJob` | ❌ 削除 |
| `GenerateStampImageJob` | ❌ 削除 |
| `Brand#generation_mode` 列 | ❌ 不要(常に manual) |
| `Linestamp::Generation` モデル | ❌ 削除(SD 試行履歴用だった) |
| `linestamp_generations` テーブル | ❌ 削除 |
| 環境変数 `SD_WEBUI_ENDPOINT` 等 | ❌ 不要 |
| `docs/linestamp/13_SD_SETUP.md` | ❌ 削除済 |

---

## 残すジョブ一覧(SD 削除後)

| ジョブ | 役割 |
|---|---|
| `DailyOrchestratorJob` | 未処理 Brand/Pack/Stamp のプロンプト合成 + 進捗 Slack 通知 |
| `ComposeBrandPromptJob` | brand.base_prompt 合成 → state: prompt_ready |
| `ComposePackSheetPromptJob` | pack.sheet_prompt 合成 |
| `ComposeStampPromptsJob` | 各 stamp.prompt 合成 |
| `ProcessStampImageJob` | raw_image(緑背景) → mini_magick → processed_image |
| `SyncBrandSourcesJob` | brand_sources/ → DB 取り込み |

---

## アップロード経路 2系統

| 経路 | 受け入れ画像 | 動作 |
|---|---|---|
| **raw アップロード** | グリーンバック(Designer 出力そのまま) | mini_magick で透過 → processed_image 生成 |
| **processed 直接アップロード** | 透過済み(Canva 仕上げ等) | そのまま attach、ChromaKey スキップ |

両方とも管理画面のフォームから上げられる。

---

## State machine の挙動(SD 削除後)

### Brand
```
planned → prompt_ready → (管理画面で base_image アップロード) → base_ready
```

`base_generating` という中間状態は不要(SDジョブが無いため)。シンプル化:
- planned → prompt_ready → base_ready

### Pack
```
planned → prompt_ready → (承認 + sheet_image アップロード) → sheet_ready → (個別 stamp 全件 processed) → complete
```

`sheet_generating` / `stamps_generating` を簡略化、UIから直接 attach できれば即遷移。

### Stamp
```
planned → prompt_ready → (raw_image アップロード) → raw_ready → (ProcessStampImageJob) → processed
                       ↘ (processed_image 直接アップロード) → processed [強制遷移]
```

---

## DB スキーマへの影響(02_DB_SCHEMA.md の修正箇所)

### linestamp_brands
- ❌ 削除: `generation_mode` 列(存在しない)
- ❌ 削除: `error_message` の SD関連用途(残してもよいが不要)

### linestamp_packs
- ❌ 削除: `error_message` の SD関連用途
- そのまま: `approved`, `approved_at`, `approver_id`

### linestamp_stamps
- ❌ 削除: `generation_meta` 列(SD seed/cfg を入れる予定だった)
- ❌ 削除: `rejection_reason` 列(SD 失敗時用)

### linestamp_generations
- ❌ テーブルごと削除

シンプルになる。

---

## 管理画面要件(整理版)

### Brand 詳細
- ✅ base_prompt の表示 + 📋 コピー
- ✅ base_image アップロード(任意の透過/非透過画像)
- ✅ base_image 表示・削除・再アップロード
- ❌ generation_mode 切替 → 不要

### Pack 詳細
- ✅ sheet_prompt の表示 + 📋 コピー
- ✅ sheet_image アップロード
- ✅ 承認チェックボックス
- ✅ 8 stamps 一覧 + 各 stamp の状態表示
- ✅ export_for_line(zip ダウンロード)
- ❌ "SDで生成" ボタン → 不要

### Stamp 詳細
- ✅ prompt の表示 + 📋 コピー
- ✅ raw_image アップロード(緑背景前提、自動透過)
- ✅ processed_image 直接アップロード(透過済前提)
- ✅ "再透過" ボタン(raw を再処理)
- ✅ リセット(画像削除して prompt_ready に戻す)
- ❌ "SDで生成" / "SD再生成" → 不要

---

## DailyOrchestratorJob(SD削除後の最終形)

```ruby
# app/jobs/linestamp/daily_orchestrator_job.rb
module Linestamp
  class DailyOrchestratorJob < ApplicationJob
    queue_as :linestamp_default

    def perform
      Rails.logger.tagged("Linestamp", "DailyOrchestrator") do
        # 1. Brand プロンプト合成: planned → prompt_ready
        Linestamp::Brand.where(state: "planned").find_each do |brand|
          Linestamp::ComposeBrandPromptJob.perform_later(brand.id)
        end

        # 2. Pack プロンプト合成: planned → prompt_ready
        #    (sheet_prompt + 8 stamps.prompt をまとめて)
        Linestamp::Pack.where(state: "planned").find_each do |pack|
          Linestamp::ComposePackSheetPromptJob.perform_later(pack.id)
          Linestamp::ComposeStampPromptsJob.perform_later(pack.id)
        end

        # 3. raw_image attached の Stamp: 透過処理 → processed
        Linestamp::Stamp.where(state: "raw_ready").find_each do |stamp|
          Linestamp::ProcessStampImageJob.perform_later(stamp.id)
        end

        # 4. Pack 完了判定: 全 stamps が processed なら complete
        Linestamp::Pack.where(state: "stamps_generating").find_each do |pack|
          pack.complete_all! if pack.may_complete_all?
        end

        # 5. 日次サマリー
        Linestamp::SlackNotifier.notify_daily_summary
      end
    end
  end
end
```

---

## 環境変数(SD削除後)

```bash
# .env (linestamp 関連だけ)

# Slack 通知
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...
SLACK_BOT_TOKEN=xoxb-...
SLACK_DEFAULT_CHANNEL=#linestamp-bot

# brand_sources 同期 webhook 認証
LINESTAMP_SYNC_TOKEN=(rails secret で生成)
```

SD 関連 ENV(`SD_WEBUI_ENDPOINT` 等)は **不要**。

---

## Gemfile(SD削除後)

```ruby
gem 'aasm'                # 状態管理(残す)
gem 'mini_magick'         # 透過処理(残す、必須)
gem 'image_processing'    # mini_magick 上位ラッパ(オプション)
gem 'slack-ruby-client'   # Slack files.upload(オプション)
gem 'kaminari'            # ページネーション
# gem 'faraday'           # SD client で使う予定だった、不要なら削除
```

---

## 利点

| 観点 | 内容 |
|---|---|
| シンプル | SD・GPU・モデル管理が不要 |
| 確実性 | Designer + mini_magick はすでに動作検証済 |
| 学習コスト | プロンプト合成と Designer の使い方だけ |
| コスト | GPU 不要、電気代も不要 |
| 品質 | Designer は安定して高品質 |

---

## 制約

| 観点 | 内容 |
|---|---|
| 自動化度 | 1スタンプ生成は手作業1〜2分(プロンプト貼り→DL→アップロード) |
| 24枚/日の負担 | 約30分の手作業/日 |
| スケール限界 | 人手依存なので 1日3パック = 24枚 が現実的上限 |

将来スケールアップしたい時は、SD 自動化を別 PR で追加検討(現時点では不要)。

---

## 14_SINGLE_ISSUE.md への反映

14 から削除する要素:
- `app/services/linestamp/stable_diffusion_client.rb`
- `app/jobs/linestamp/generate_brand_base_image_job.rb`
- `app/jobs/linestamp/generate_pack_sheet_image_job.rb`
- `app/jobs/linestamp/generate_stamp_image_job.rb`
- DB マイグレーション: `linestamp_generations` テーブル
- DB マイグレーション: `linestamp_brands.generation_mode` 列
- Stamp / Pack の SD 関連カラム
- 環境変数 SD 関連
- Gemfile の SD クライアント関連 gem(faraday は他用途で残してOK)

14 に残す要素:
- 全ての md ソース・テンプレート
- Rails モデル(Generation 除く)
- Compose系プロンプト合成 Job
- mini_magick 透過 Job
- 管理画面(全機能、アップロード経路含む)
- GitHub Actions(企画 workflow)
- Webhook + sync
