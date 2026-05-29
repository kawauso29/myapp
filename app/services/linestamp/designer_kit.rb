# frozen_string_literal: true

require "tempfile"

module Linestamp
  module DesignerKit
    # Stamp 1枚分の Designer 作業キット(prompt + 参照画像 + 手順書)を zip で返す。
    class Stamp
      def initialize(stamp)
        @stamp = stamp
      end

      # Returns a Tempfile containing the ZIP
      def export
        zip = Tempfile.new(["designer_kit_stamp_#{@stamp.id}_", ".zip"])
        Zip::OutputStream.open(zip.path) do |zos|
          zos.put_next_entry("prompt.txt")
          zos.write(@stamp.prompt.to_s)

          zos.put_next_entry("README.md")
          zos.write(readme_text)

          brand = @stamp.pack.brand
          if brand.base_image.attached?
            zos.put_next_entry("references/brand_base.png")
            zos.write(brand.base_image.download)
          end
          if @stamp.pack.sheet_image.attached?
            zos.put_next_entry("references/pack_sheet.png")
            zos.write(@stamp.pack.sheet_image.download)
          end
        end
        zip
      end

      def filename
        brand_slug = @stamp.pack.brand.slug
        pack_slug = @stamp.pack.slug
        position = @stamp.position.to_s.rjust(2, "0")
        "designer_kit_#{brand_slug}_#{pack_slug}_#{position}.zip"
      end

      private

      def readme_text
        <<~TEXT
          # Stamp ##{@stamp.position} 「#{@stamp.display_label}」

          ## Designer に渡す手順
          1. prompt.txt の中身をコピーして Designer(画像生成)に貼る
          2. references/brand_base.png と references/pack_sheet.png を参照画像として添付する
          3. 生成 → ダウンロード
          4. 管理画面の「Raw アップロード」で再アップロードする

          ## このスタンプの要点
          - シチュエーション: #{@stamp.situation}
          - 送り手の意図: #{@stamp.intent}
          - 利用シーン: #{@stamp.usage_scene}
        TEXT
      end
    end
  end
end
