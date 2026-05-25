# 05. Sidekiq ジョブ仕様

## ジョブ一覧と責務

| ジョブ | 入力 | 出力(状態遷移) |
|---|---|---|
| `DailyOrchestratorJob` | (なし、cron起動) | 未処理プロンプト合成をディスパッチ + 透過処理 |
| `ComposeBrandPromptJob` | brand_id | brand: planned → prompt_ready |
| `ComposeStampPromptsJob` | pack_id | stamps: planned → prompt_ready |
| `ComposePackSheetPromptJob` | pack_id | pack: planned → prompt_ready |
| `ProcessStampImageJob` | stamp_id | stamp: raw_ready → processed |
| `SyncBrandSourcesJob` | (なし) | brand_sources/ → DB sync |

**作らないジョブ**: `GenerateBrandBaseImageJob` / `GeneratePackSheetImageJob` / `GenerateStampImageJob`
(SD 自動生成ルートを採用しないため)。画像は管理画面から原田さんがアップロード。

各ジョブは **冪等** に作る:
- 開始時に現在の状態を確認、対象外なら何もせず終了
- 状態遷移は AASM の guard / `may_xxx?` で安全に

---

## 1. DailyOrchestratorJob

毎朝起動。未処理レコードを Job キューに積む。

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

        # 2. Pack プロンプト合成(sheet + stamps × 8 をまとめて)
        Linestamp::Pack.where(state: "planned").find_each do |pack|
          Linestamp::ComposePackSheetPromptJob.perform_later(pack.id)
          Linestamp::ComposeStampPromptsJob.perform_later(pack.id)
        end

        # 3. raw_image が attach 済の Stamp: 透過処理 → processed
        Linestamp::Stamp.where(state: "raw_ready").find_each do |stamp|
          Linestamp::ProcessStampImageJob.perform_later(stamp.id)
        end

        # 4. Pack 完了判定: 全 stamps が processed なら complete に遷移
        Linestamp::Pack.where(state: "stamps_generating").find_each do |pack|
          pack.complete_all! if pack.may_complete_all?
        end

        # 5. 日次サマリーを Slack へ
        Linestamp::SlackNotifier.notify_daily_summary
      end
    end
  end
end
```

**SD 自動生成ジョブは存在しません**。画像取得は管理画面でのアップロード経由(下記コントローラ参照)。

---

## 2. ComposeBrandPromptJob

```ruby
# app/jobs/linestamp/compose_brand_prompt_job.rb
module Linestamp
  class ComposeBrandPromptJob < ApplicationJob
    queue_as :linestamp_compose

    def perform(brand_id)
      brand = Linestamp::Brand.find(brand_id)
      return unless brand.state == "planned"

      composer = Linestamp::PromptComposer.new(brand: brand)
      brand.update!(base_prompt: composer.compose_for_brand_base)
      brand.ready_prompt!
    rescue => e
      brand.fail!(e.message) if brand&.may_fail?
      raise
    end
  end
end
```

---

## 3. ComposePackSheetPromptJob

```ruby
module Linestamp
  class ComposePackSheetPromptJob < ApplicationJob
    queue_as :linestamp_compose

    def perform(pack_id)
      pack = Linestamp::Pack.find(pack_id)
      return unless pack.state == "planned"

      composer = Linestamp::PromptComposer.new(pack: pack)
      pack.update!(sheet_prompt: composer.compose_for_pack_sheet)
      pack.ready_prompt!
    rescue => e
      pack.fail!(e.message) if pack&.may_fail?
      raise
    end
  end
end
```

## 4. ComposeStampPromptsJob

```ruby
module Linestamp
  class ComposeStampPromptsJob < ApplicationJob
    queue_as :linestamp_compose

    def perform(pack_id)
      pack = Linestamp::Pack.find(pack_id)
      pack.stamps.where(state: "planned").find_each do |stamp|
        composer = Linestamp::PromptComposer.new(pack: pack, stamp: stamp)
        stamp.update!(prompt: composer.compose_for_stamp)
        stamp.ready_prompt!
      end
    end
  end
end
```

---

## 5. ProcessStampImageJob

```ruby
module Linestamp
  class ProcessStampImageJob < ApplicationJob
    queue_as :linestamp_process
    sidekiq_options retry: 3

    def perform(stamp_id)
      stamp = Linestamp::Stamp.find(stamp_id)
      return unless stamp.state == "raw_ready"
      return unless stamp.raw_image.attached?

      raw_path = save_attachment_to_tempfile(stamp.raw_image)
      processor = Linestamp::ChromaKeyProcessor.new
      output_file = processor.call(raw_path.path)

      stamp.processed_image.attach(
        io: output_file,
        filename: "stamp_#{format('%02d', stamp.number)}_#{stamp.label}.png",
        content_type: "image/png"
      )
      stamp.complete_processing!

      Linestamp::SlackNotifier.notify_stamp_completed(stamp)
    rescue => e
      stamp.fail!(e.message) if stamp&.may_fail?
      raise
    ensure
      raw_path&.close
      raw_path&.unlink
    end

    private

    def save_attachment_to_tempfile(attachment)
      f = Tempfile.new(["attached", ".png"], binmode: true)
      attachment.download { |chunk| f.write(chunk) }
      f.rewind
      f
    end
  end
end
```

---

## キュー設定 (sidekiq.yml)

```yaml
# config/sidekiq.yml
:concurrency: 5
:queues:
  - [linestamp_default, 3]
  - [linestamp_compose, 4]   # プロンプト合成、軽量・並列OK
  - [linestamp_process, 2]   # mini_magick 透過、軽い
```

`linestamp_generate` キューは不要(SD ジョブが無いため)。

## スケジューラ (sidekiq-cron)

```yaml
# config/schedule.yml に追加
linestamp_daily_orchestrator:
  cron: "0 8 * * *"  # 毎朝8時
  class: "Linestamp::DailyOrchestratorJob"
  queue: linestamp_default
  description: "LINEスタンプ工房 日次パイプライン"
```
