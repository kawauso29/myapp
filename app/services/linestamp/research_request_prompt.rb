# frozen_string_literal: true

# Cowork(対話AI)に週次リサーチを依頼するためのプロンプトを合成するサービス。
#
# 設計方針(2026-06 の運用転換):
#   - プロンプトの実態は Rails 側が握り、Cowork は触らない。
#   - 過去のリサーチ履歴・既存ブランドの差別化情報・master slug 辞書を
#     実行時に PG から注入し、「既存と被らない」新規リサーチを生成させる。
#   - 出力フォーマットは Importer DSL seed(research_template.rb 準拠)で固定する。
#
# 使い方:
#   Linestamp::ResearchRequestPrompt.new(target_date: Date.current.next_week).compose
class Linestamp::ResearchRequestPrompt
  AXES = %w[tone motif demographic setting].freeze

  def initialize(target_date: Date.current.next_week)
    @target_date = target_date
  end

  def week_label
    format("%<year>d-W%<week>02d", year: @target_date.cwyear, week: @target_date.cweek)
  end

  def research_slug
    "weekly_trends_#{@target_date.cwyear}_w#{@target_date.cweek}"
  end

  def target_range
    monday = @target_date.beginning_of_week(:monday)
    sunday = monday + 6
    "#{monday.strftime('%-m/%-d')}〜#{sunday.strftime('%-m/%-d')}"
  end

  def seed_id
    "#{Time.current.strftime('%Y-%m-%d-%H%M%S')}_research_#{week_label}"
  end

  def brands_count
    existing_brands.size
  end

  def researches_count
    research_history.size
  end

  def compose
    <<~PROMPT
      # 役割
      あなたはLINEスタンプ事業の週次リサーチ担当。目的は、後続のブランド企画が
      消費する「素材」を作ること。最終成果物は Rails の Importer DSL seed ファイル1本。

      # 対象週
      - 今日: #{Date.current.strftime('%Y-%m-%d')}
      - 対象週: #{week_label}(#{target_range})

      # やること
      1. web_search で対象週の日本の文脈を調査する:
         季節・天候(梅雨/猛暑など)・行事/記念日・SNSで増える定番セリフ・
         気分/体調の話題・LINEスタンプ市場で伸びる用途。
      2. 「見た目のかわいさ」ではなく「どの場面で即決で使うか(用途設計)」を軸に分析する。
      3. 後続のブランド企画用に、差別化された候補ブランド案を A〜D で出す。
         各案は silhouette(黒塗りでも識別できる全体形)と 中心CT を必ず添える。

      # 重複回避(重要)
      以下と被るテーマ／シルエット／占有色は避けること。

      ## これまでの調査履歴(#{researches_count}件)
      #{research_history_block}

      ## 既存ブランド(#{brands_count}件 / slug ・ キャラ ・ silhouette ・ 占有色 ・ CT)
      #{existing_brands_block}

      # 使ってよい slug 辞書(これ以外を書くと apply が ArgumentError で失敗する)
      ## communication_themes
      #{ct_dictionary_block}
      ## attribute values
      #{attribute_dictionary_block}
      ※ keywords / emotions / seasons は自由記述。
        communication_themes と attributes は必ず上の辞書内の slug のみを使う。

      # 出力フォーマット(厳守)
      - 返答は seed ファイルの中身のみ。前後に説明文を付けない。
      - 保存先: db/seeds/linestamp/imports/pending/#{seed_id}.rb
      - brand_ideas は A〜D を具体的に(過去の実績と同等の密度で)。
      - prompt 系カラムや background_color は研究 seed には存在しない。触らない。

      ```ruby
      # frozen_string_literal: true
      Linestamp::Importer.run(seed_id: "#{seed_id}") do
        upsert_research!(
          slug: "#{research_slug}",
          title: "LINEスタンプ週次調査 #{week_label}(…要点…)",
          body: "…対象週の状況を3〜5文で…",
          findings: "1) … 2) … 3) … 4) … 5) …(用途×CTで)",
          brand_ideas: "A) …(silhouette/中心CT) B) … C) … D) …",
          line_market_insights: "…市場の用途設計の洞察…",
          communication_substitute_needs: "…『〜したい』の代替ニーズを列挙…",
          source_url: "https://…",
          keywords: %w[…],
          emotions: %w[…],
          seasons: %w[…],
          communication_themes: %w[…辞書から…],
          attributes: {
            tone: %w[…], motif: %w[…], demographic: %w[…], setting: %w[…]
          }
        )
      end
      ```
    PROMPT
  end

  private

  def existing_brands
    @existing_brands ||= ::Linestamp::Brand
      .includes(:communication_themes)
      .order(:slug)
      .to_a
  end

  def research_history
    @research_history ||= ::Linestamp::Research
      .order(created_at: :desc)
      .to_a
  end

  def existing_brands_block
    return "(まだ既存ブランドはありません)" if existing_brands.empty?

    existing_brands.map do |b|
      ax = b.identity_axes || {}
      silhouette = ax["silhouette"].presence || "(未設定)"
      color = ax["signature_color"].presence || b.primary_color
      cts = b.communication_themes.map(&:slug).sort.join(", ")
      cts = "(なし)" if cts.blank?
      "- #{b.slug} / #{b.character_name} / silhouette: #{silhouette} / 占有色: #{color} / CT: #{cts}"
    end.join("\n")
  end

  def research_history_block
    return "(まだ調査履歴はありません)" if research_history.empty?

    research_history.map { |r| "- #{r.slug.presence || '(slug未設定)'}: #{r.title}" }.join("\n")
  end

  def ct_dictionary_block
    ::Linestamp::CommunicationTheme.active.ordered.map { |ct| "  #{ct.slug} — #{ct.name}" }.join("\n")
  end

  def attribute_dictionary_block
    AXES.map do |axis|
      slugs = ::Linestamp::AttributeValue.for_axis(axis).active.ordered.pluck(:slug).join(" ")
      format("  %-12s %s", "#{axis}:", slugs)
    end.join("\n")
  end
end
