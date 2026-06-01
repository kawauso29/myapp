# frozen_string_literal: true

Linestamp::Importer.run(seed_id: "2026-06-01-002231_research_2026-W23") do
  upsert_research!(
    slug: "weekly_trends_2026_w23",
    title: "LINEスタンプ週次調査 2026-W23（梅雨本番・低負荷コミュニケーション需要）",
    body: "2026-W23は全国的な梅雨入り進行で、天候不安定・湿度上昇による疲労感共有の会話が増加。平日昼は『短く即返せる業務連絡』、夜間は『しんどさをやわらかく伝える共感表現』が伸びる。雨天移動の遅延連絡と、相手の体調を気づかうワンアクション需要が同時に高まる週。",
    findings: "1) 雨天・低気圧で quick_answer/status_busy/need_break の短文ニーズが継続増。2) 通勤遅延・到着見込み共有で on_the_way/urgent_contact/confirm_meetup の実用系テーマが活性化。3) 梅雨のだるさ・冷えによる『無理しないで』文脈で encouragement/appreciation_for_effort の感情ケア需要が拡大。4) 週初は greeting_morning + remote_work_report の定型報告、週末前は meal_invitation で気分転換の誘いが伸長。5) 感情強度よりも『相手に負担をかけない丁寧な省エネ表現』が選ばれる傾向。",
    brand_ideas: "A)『しっとり連絡ペンギン』: 雨の日の遅延・到着連絡を前向きに伝える実務特化。B)『むりしないカワウソ』: 体調気づかいと自己申告をやさしく代弁する共感系。C)『既読はやい豆しば』: 1〜5文字中心の即レス運用を可愛く支える業務私用ハイブリッド。D)『おつかれ巡回くま』: ねぎらい・励まし・朝夕挨拶を日常導線で回せる定番設計。",
    line_market_insights: "W23の市場は『かわいさ単体』より『即利用できる状況適合性』が購入理由になりやすい。特に梅雨期は、天候起点の会話開始→状況共有→ねぎらいまでを1セットで完結できる構成が強い。ビジネス層では丁寧語短文、プライベート層では体調気づかい文が併用されるため、同一キャラ内でフォーマル/カジュアルの言い換えペアを持つ企画が有効。",
    communication_substitute_needs: "『文章を組み立てる余力がない時に、失礼なく近況を返したい』『雨や体調由来の遅れ・不調を角を立てず伝えたい』『相手の疲れに短く寄り添いたい』という代替ニーズが強い。",
    source_url: "https://www.line.me/ja/",
    keywords: %w[LINEスタンプ 週次調査 2026W23 梅雨 低気圧 即レス 体調気づかい 遅延連絡],
    emotions: %w[安心 共感 労り 気遣い 前向き],
    seasons: %w[rainy_season early_summer],
    communication_themes: %w[
      quick_answer
      status_busy
      need_break
      on_the_way
      urgent_contact
      confirm_meetup
      encouragement
      appreciation_for_effort
      greeting_morning
      remote_work_report
      meal_invitation
    ],
    attributes: {
      tone: %w[gentle cute neat],
      motif: %w[animal tool plant],
      demographic: %w[age_20s age_30s age_40s business_user unisex],
      setting: %w[remote_work office home with_friends with_family boss_subordinate]
    }
  )
end
