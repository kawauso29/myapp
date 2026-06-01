# frozen_string_literal: true

Linestamp::Importer.run(seed_id: "2026-06-01-065216_research_2026-W23") do
  upsert_research!(
    slug: "weekly_trends_2026_w23",
    title: "LINEスタンプ週次調査 2026-W23（梅雨本番・低気圧ケアと短文気づかい需要）",
    body: "2026-W23は梅雨本番に入り、天候不安定による体調ゆらぎ共有と、返信負荷を下げる短文コミュニケーションが同時に伸長。平日昼は業務の即時共有、夕方〜夜は『無理しないで』『先に休んで』系の感情ケア需要が強い。季節要素（雨・傘・湿気・洗濯）を会話導入に使い、実務連絡へ自然接続できる設計が有効。",
    findings: "1) 雨天時は quick_answer/status_busy/need_break の『角が立たない即レス』が使用増。2) 遅延・到着連絡は on_the_way/confirm_meetup/urgent_contact の実務系が安定需要。3) 低気圧不調やだるさ共有では gratitude/appreciation_for_effort/encouragement を添えると既読スルー回避に寄与。4) 朝夕の挨拶は greeting_morning/greeting_night の季節文脈付き（雨だね・冷えるね）が反応良好。5) 週末手前は meal_invitation/celebration の『小さな回復行動』導線が購買意図を押し上げる。",
    brand_ideas: "A) 『しっとり労りラッコ』: 雨の日の体調気づかい・ねぎらいを柔らかい敬語で返せる。B) 『秒レスてるてるハム』: 1〜5文字中心の超短文で、業務/私用どちらも崩れない。C) 『移動中ペンギン便』: 遅延・到着・待ち合わせ確認に特化した実務連絡パック前提。D) 『梅雨ぬけ希望ネコ』: だるさ共有から励ましへ橋渡しする情緒ケア型。",
    line_market_insights: "市場は『かわいい見た目単体』より『用途別に迷わず選べる導線』が優位。特に梅雨期は、天候起点の一言→状況共有→気づかい返答の3段会話に対応できるセットが再利用されやすい。ビジネス層では丁寧さを保った短文、私用では共感を先に置く短文が支持され、同一キャラで両文脈を跨げる設計が差別化要因になる。",
    communication_substitute_needs: "『長文を打つ余力がない時でも、冷たく見せずに状況共有したい』『遅延や不調を角を立てず伝えたい』『相手のしんどさに即反応して安心感を返したい』という代替ニーズが強い。",
    source_url: "https://www.line.me/ja/",
    keywords: %w[LINEスタンプ 週次調査 2026W23 梅雨 低気圧 体調気づかい 即レス 実務連絡],
    emotions: %w[安心 共感 労り 気遣い 前向き],
    seasons: %w[rainy_season early_summer],
    communication_themes: %w[
      quick_answer
      status_busy
      need_break
      appreciation_for_effort
      gratitude
      encouragement
      greeting_morning
      greeting_night
      on_the_way
      confirm_meetup
      urgent_contact
      meal_invitation
      celebration
    ],
    attributes: {
      tone: %w[gentle cute neat],
      motif: %w[animal plant tool],
      demographic: %w[age_20s age_30s age_40s business_user unisex],
      setting: %w[remote_work office home with_friends with_family with_customer]
    }
  )
end
