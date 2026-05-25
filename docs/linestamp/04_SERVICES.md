# 04. サービス層仕様

## 一覧

| サービス | 役割 |
|---|---|
| `Linestamp::BrandSourcesSyncer` | brand_sources/ 配下のmd → DB 同期 |
| `Linestamp::PromptComposer` | mdソース → Designer 用プロンプト合成(管理画面表示用) |
| `Linestamp::ChromaKeyProcessor` | mini_magick で緑透過 + LINE規格 |
| `Linestamp::SlackNotifier` | Slack 通知(Webhook + files.upload) |
| `Linestamp::LineExporter` | LINE申請用 zip (01.png〜08.png) 生成 |
| `Linestamp::Seeders::Nemuinu` | ねむ犬既存資産の seed |

**`Linestamp::StableDiffusionClient` は採用しません**(SD ルート不採用)。

---

## 1. BrandSourcesSyncer

`brand_sources/` のmdソースを DB に同期。冪等。

```ruby
# app/services/linestamp/brand_sources_syncer.rb
module Linestamp
  class BrandSourcesSyncer
    BRAND_SOURCES_ROOT = Rails.root.join("brand_sources")

    def call
      sync_researches
      sync_brands
      sync_packs_and_stamps
    end

    private

    def sync_researches
      Dir.glob(BRAND_SOURCES_ROOT.join("research/*/findings.md")).each do |path|
        slug = File.basename(File.dirname(path))  # "2026-W21"
        brief_path = File.dirname(path) + "/brief.md"
        brief = File.exist?(brief_path) ? File.read(brief_path) : ""
        findings_md = File.read(path)
        trends_path = File.dirname(path) + "/trends.yml"
        trends = File.exist?(trends_path) ? YAML.load_file(trends_path) : {}

        Research.find_or_create_by!(slug: slug) do |r|
          r.brief = brief
          r.findings_md = findings_md
          r.trends = trends
          r.source_path = path.sub(Rails.root.to_s + "/", "")
        end
      end
    end

    def sync_brands
      Dir.glob(BRAND_SOURCES_ROOT.join("*/01_brand_theme.md")).each do |theme_path|
        brand_dir = File.dirname(theme_path)
        slug = File.basename(brand_dir)
        next if slug.start_with?("_")  # _templates 等

        meta_path = brand_dir + "/meta.yml"
        meta = File.exist?(meta_path) ? YAML.load_file(meta_path) : {}

        brand = Brand.find_or_initialize_by(slug: slug)
        brand.assign_attributes(
          series_name:    meta["series_name"]    || slug,
          character_name: meta["character_name"] || slug,
          brand_theme_md: File.read(theme_path),
          base_md:        File.read(brand_dir + "/02_base.md"),
          research:       meta["research_slug"] ? Research.find_by(slug: meta["research_slug"]) : nil,
        )
        brand.save!
      end
    end

    def sync_packs_and_stamps
      Dir.glob(BRAND_SOURCES_ROOT.join("*/packs/*/03_stamp_pack.md")).each do |pack_md_path|
        pack_dir = File.dirname(pack_md_path)
        pack_slug = File.basename(pack_dir)
        brand_slug = File.basename(File.dirname(File.dirname(pack_dir)))

        brand = Brand.find_by!(slug: brand_slug)
        manifest = YAML.load_file(pack_dir + "/manifest.yml")

        pack = brand.packs.find_or_initialize_by(slug: pack_slug)
        pack.assign_attributes(
          series_theme: manifest["series_theme"] || pack_slug,
          pack_md:      File.read(pack_md_path),
          layer:        manifest["layer"],
        )
        pack.save!

        # 8枚のstampを upsert
        manifest["stamps"].each do |stamp_data|
          stamp = pack.stamps.find_or_initialize_by(number: stamp_data["number"])
          stamp.assign_attributes(
            label:     stamp_data["label"],
            situation: stamp_data["situation"],
          )
          stamp.save!
        end
      end
    end
  end
end
```

---

## 2. PromptComposer

mdソース + 補助情報から **Designer 用プロンプト**を合成。
管理画面に表示・コピー → 原田さんが Copilot Chat の Designer に貼る。
**ロジックのみ、本文はmd側**。

```ruby
# app/services/linestamp/prompt_composer.rb
module Linestamp
  class PromptComposer
    DEFAULT_NEGATIVE_NOTE = "崩れた漢字や複数スタンプは避け、再生成してください"

    def initialize(brand: nil, pack: nil, stamp: nil)
      @brand = brand
      @pack  = pack
      @stamp = stamp
    end

    # Phase 1: ブランドベース画像生成プロンプト
    def compose_for_brand_base
      <<~PROMPT.strip
        #{extract_section(@brand.brand_theme_md, "OK な方向")}
        #{extract_section(@brand.base_md, "強制プロンプト")}

        Style: anime sticker style, simple linework, soft pastel.
        Background: solid green (#3CB371) for chroma key removal.
        Output: character standard pose, multiple facial expressions reference sheet.
      PROMPT
    end

    # Phase 2: パックシート(8枚一覧)生成プロンプト
    def compose_for_pack_sheet
      stamps_desc = @pack.stamps.order(:number).map do |s|
        "##{s.number}: 「#{s.label}」 #{s.situation}"
      end.join("\n")

      <<~PROMPT.strip
        #{extract_section(@pack.brand.brand_theme_md, "ねむそう")}
        #{@pack.pack_md}

        Generate an 8-stamp overview sheet (2 rows × 4 columns).
        Each stamp shows the character with the described situation:
        #{stamps_desc}

        Style: consistent across all 8 frames.
        Background: solid green.
        Text on each stamp follows: 太丸・濃ブラウン・太い白フチ.
      PROMPT
    end

    # Phase 3: 個別スタンプ生成プロンプト
    def compose_for_stamp
      <<~PROMPT.strip
        #{@pack.pack_md}

        Generate one stamp:
        Number: ##{@stamp.number}
        Label: 「#{@stamp.label}」
        Situation: #{@stamp.situation}

        Character spec:
        - 白い2頭身、細い半目(必須・丸目禁止)、小さい口、水色首輪+タグ
        - 「眠そうだけどちゃんとやってる犬」(かわいい犬ではない)

        Text rendering:
        - 文言: 「#{@stamp.label}」(中央上部に配置)
        - スタイル: 太丸・濃ブラウン・太い白フチ
        - 漢字は正しく丁寧に描く

        Output:
        - 1画像1スタンプ
        - 背景: 単色グリーン
        - 正方形
      PROMPT
    end

    # Designer の対応次第で参考扱い
    def compose_negative_note
      DEFAULT_NEGATIVE_NOTE
    end

    private

    # md 内の `## セクション名` を抽出。なければ全体を返す
    def extract_section(md_text, section_name)
      return md_text unless md_text.match?(/^##\s+#{Regexp.escape(section_name)}/m)
      md_text.split(/^##\s+/).find { |s| s.start_with?(section_name) }.to_s.strip
    end
  end
end
```

---

## 3. ChromaKeyProcessor (mini_magick)

緑透過 → LINE規格(370×320) 整形。

```ruby
# app/services/linestamp/chroma_key_processor.rb
require "mini_magick"

module Linestamp
  class ChromaKeyProcessor
    LINE_W = 370
    LINE_H = 320
    MARGIN = 10
    CONTENT_W = LINE_W - MARGIN * 2  # 350
    CONTENT_H = LINE_H - MARGIN * 2  # 300
    FUZZ_PCT  = 25  # 緑判定の色空間距離許容%
    SPILL_REDUCE = 0.85  # 緑チャンネル抑制倍率

    # @param input_path [String]
    # @return [Tempfile] LINE規格透過済みPNG
    def call(input_path)
      output = Tempfile.new(["chroma_out", ".png"], binmode: true)
      output.close

      MiniMagick::Tool::Convert.new do |c|
        c << input_path

        # 1. 緑だけ透過。白(R=G=B)は彩度0なので絶対残る
        c.fuzz "#{FUZZ_PCT}%"
        c.transparent "green"

        # 2. グリーンスピル抑制(緑のフチを消す)
        c.channel "G"
        c.evaluate "Multiply", SPILL_REDUCE.to_s
        c.channel "RGBA"

        # 3. 透明領域を自動トリム
        c.trim
        c.merge! ["+repage"]

        # 4. LINE規格にフィット(アスペクト比保持、10pxマージン込み)
        c.background "none"
        c.resize "#{CONTENT_W}x#{CONTENT_H}>"  # ">" は拡大しない
        c.gravity "center"
        c.extent "#{LINE_W}x#{LINE_H}"

        c << output.path
      end

      Tempfile.open(["chroma_result", ".png"], binmode: true) do |f|
        f.write(File.binread(output.path))
        f.rewind
        return f
      end
    ensure
      output&.unlink
    end

    # 動作確認用: 緑残りが許容範囲内かチェック
    def quality_check(output_path)
      image = MiniMagick::Image.open(output_path)
      # アルファ0以外のピクセルで RGB の緑成分が突出してたら警告
      # (実装簡略)
      image.dimensions == [LINE_W, LINE_H]
    end
  end
end
```

---

## 4. SlackNotifier

Webhook で通常通知、files.upload で画像送付。

```ruby
# app/services/linestamp/slack_notifier.rb
require "faraday"
require "slack-ruby-client"

module Linestamp
  class SlackNotifier
    WEBHOOK_URL = ENV.fetch("SLACK_WEBHOOK_URL")
    BOT_TOKEN   = ENV["SLACK_BOT_TOKEN"]  # files.upload 用、任意
    DEFAULT_CHANNEL = ENV.fetch("SLACK_DEFAULT_CHANNEL", "#linestamp-bot")

    def self.notify(text:, blocks: nil)
      payload = { text: text }
      payload[:blocks] = blocks if blocks
      Faraday.post(WEBHOOK_URL, payload.to_json, "Content-Type" => "application/json")
    end

    def self.notify_stamp_completed(stamp)
      blocks = [
        { type: "header", text: { type: "plain_text", text: "✅ stamp完成" } },
        { type: "section", text: { type: "mrkdwn",
            text: "*#{stamp.brand.character_name}* / pack: `#{stamp.pack.slug}` / ##{stamp.number}\n`#{stamp.label}`" } }
      ]
      notify(text: "stamp完成: #{stamp.label}", blocks: blocks)

      upload_image(stamp.processed_image, filename: "stamp_#{stamp.number}_#{stamp.label}.png",
                   title: stamp.label) if BOT_TOKEN && stamp.processed_image.attached?
    end

    def self.notify_daily_summary
      stats = {
        brands_planned:   Linestamp::Brand.where(state: "planned").count,
        brands_ready:     Linestamp::Brand.where(state: "base_ready").count,
        packs_pending:    Linestamp::Pack.pending_approval.count,
        packs_approved:   Linestamp::Pack.approved.where.not(state: "complete").count,
        packs_complete:   Linestamp::Pack.where(state: "complete").count,
        stamps_processed: Linestamp::Stamp.where(state: "processed").count,
      }

      blocks = [
        { type: "header", text: { type: "plain_text", text: "📊 LINEスタンプ 日次サマリー" } },
        { type: "section", fields: stats.map { |k, v| { type: "mrkdwn", text: "*#{k}*: #{v}" } } },
        { type: "context", elements: [{ type: "mrkdwn", text: "<https://your-rails-host/admin/linestamp/packs|管理画面で確認>" }] }
      ]

      notify(text: "LINEスタンプ 日次サマリー", blocks: blocks)
    end

    def self.upload_image(attachment, filename:, title:)
      return unless BOT_TOKEN

      client = Slack::Web::Client.new(token: BOT_TOKEN)
      Tempfile.create(["upload", ".png"]) do |f|
        f.binmode
        attachment.download { |chunk| f.write(chunk) }
        f.rewind
        client.files_upload(
          channels: DEFAULT_CHANNEL,
          file: Faraday::UploadIO.new(f.path, "image/png"),
          filename: filename,
          title: title
        )
      end
    end
  end
end
```

---

## 5. LineExporter

LINE申請用に `01.png〜08.png` 命名で zip 化。

```ruby
# app/services/linestamp/line_exporter.rb
require "zip"

module Linestamp
  class LineExporter
    def initialize(pack)
      @pack = pack
    end

    # @return [String] zip ファイルのバイナリ
    def zip
      Zip::OutputStream.write_buffer do |zos|
        @pack.stamps.order(:number).each do |stamp|
          next unless stamp.processed_image.attached?
          filename = format("%02d.png", stamp.number)
          zos.put_next_entry(filename)
          stamp.processed_image.download { |chunk| zos.write(chunk) }
        end
      end.string
    end
  end
end
```

Gemfile に `gem 'rubyzip'` を追加。

---

## 6. Seeders::Nemuinu

ねむ犬の既存資産を初期 seed。

```ruby
# app/services/linestamp/seeders/nemuinu.rb
module Linestamp
  module Seeders
    class Nemuinu
      def call
        ActiveRecord::Base.transaction do
          # brand_sources/nemuinu/ が既に置かれている前提
          Linestamp::BrandSourcesSyncer.new.call

          brand = Linestamp::Brand.find_by!(slug: "nemuinu")

          # 引継ぎ済 base.png があれば attach
          base_path = Rails.root.join("brand_sources/nemuinu/base.png")
          brand.base_image.attach(io: File.open(base_path), filename: "base.png") if base_path.exist?
          brand.complete_base! if brand.may_complete_base? && brand.base_image.attached?

          # pack_001 の processed_image があれば attach
          pack = brand.packs.find_by!(slug: "pack_001")
          pack.stamps.order(:number).each do |stamp|
            processed_path = Rails.root.join(
              "brand_sources/nemuinu/packs/pack_001/output/stamp_#{stamp.number.to_s.rjust(2, '0')}_#{stamp.label}.png"
            )
            stamp.processed_image.attach(io: File.open(processed_path), filename: processed_path.basename.to_s) if processed_path.exist?
          end
        end
      end
    end
  end
end
```
