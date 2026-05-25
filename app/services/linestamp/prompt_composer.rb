module Linestamp
  class PromptComposer
    BRAND_TEMPLATE = <<~PROMPT
      あなたはLINEスタンプのキャラクターデザイナーです。
      以下のブランド情報をもとに、基本キャラクター画像の生成プロンプトを作成してください。

      ## ブランド情報
      - ブランド名: %{brand_name}
      - 説明: %{description}

      ## ソースドキュメント
      %{source_docs}

      ## 出力要件
      - 緑背景（#00FF00）の正面向きキャラクター
      - LINEスタンプとして視認性が高いデザイン
      - シンプルで表情差分が作りやすいデザイン
    PROMPT

    PACK_SHEET_TEMPLATE = <<~PROMPT
      あなたはLINEスタンプのパックデザイナーです。
      以下のパック情報をもとに、スタンプシート全体のデザインプロンプトを作成してください。

      ## ブランド: %{brand_name}
      ## パック: %{pack_title}（#%{position}）

      ## 基本キャラクター設定
      %{brand_prompt}

      ## パック固有の要件
      %{source_docs}

      ## 出力要件
      - 8〜40個のスタンプで構成
      - 各スタンプに感情/テキストの指示を含む
      - 日常会話で使える表現を優先
    PROMPT

    STAMP_TEMPLATE = <<~PROMPT
      あなたはLINEスタンプの個別デザイナーです。
      以下の情報をもとに、1つのスタンプ画像の生成プロンプトを作成してください。

      ## ブランド: %{brand_name}
      ## パック: %{pack_title}
      ## スタンプ #%{position}

      ## 基本キャラクター設定
      %{brand_prompt}

      ## このスタンプの要件
      - 感情: %{emotion}
      - テキスト: %{text_overlay}

      ## 画像仕様
      - サイズ: 370x320px
      - 背景: 緑（#00FF00）→ 後で透過処理
      - キャラクターがスタンプ領域の80%%以上を占める
    PROMPT

    def compose_brand_prompt(brand)
      source_docs = load_brand_sources(brand)
      format(BRAND_TEMPLATE, brand_name: brand.name, description: brand.description, source_docs: source_docs)
    end

    def compose_pack_sheet_prompt(pack)
      source_docs = load_pack_sources(pack)
      format(
        PACK_SHEET_TEMPLATE,
        brand_name: pack.brand.name,
        pack_title: pack.title,
        position: pack.position,
        brand_prompt: pack.brand.brand_prompt,
        source_docs: source_docs
      )
    end

    def compose_stamp_prompt(stamp)
      pack = stamp.pack
      format(
        STAMP_TEMPLATE,
        brand_name: pack.brand.name,
        pack_title: pack.title,
        position: stamp.position,
        brand_prompt: pack.brand.brand_prompt,
        emotion: stamp.emotion || "なし",
        text_overlay: stamp.text_overlay || "なし"
      )
    end

    private

    def load_brand_sources(brand)
      dir = Rails.root.join("brand_sources", brand.slug)
      return "" unless dir.exist?

      Dir.glob(dir.join("*.md")).sort.map { |f| File.read(f) }.join("\n\n---\n\n")
    end

    def load_pack_sources(pack)
      dir = Rails.root.join("brand_sources", pack.brand.slug, "packs", "pack_#{pack.position.to_s.rjust(3, '0')}")
      return "" unless dir.exist?

      Dir.glob(dir.join("*.md")).sort.map { |f| File.read(f) }.join("\n\n---\n\n")
    end
  end
end
