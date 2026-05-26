# frozen_string_literal: true

Linestamp::Importer.run(seed_id: "2026-05-26-041156_research_2026-W22") do
  upsert_research!(
    slug: "weekly_trends_2026_w22",
    title: "LINEスタンプ週次調査 2026-W22（梅雨入り前後・短文即レス需要）",
    body: "2026-W22は、梅雨入り前後の気圧・天候要因で『体調気づかい』『短文での状況共有』ニーズが伸長。平日昼は業務連絡の簡潔化、夜間は疲労共有とねぎらい系の使用が目立つ。家族・同僚・友人の3文脈で使い回せる言い換え表現と、感情を和らげるトーン設計が有効。",
    findings: "1) 低気圧・雨天で長文を避ける傾向が強まり、quick_answer/need_break/status_busy系の短文需要が増加。2) 通勤・外出遅延の共有で on_the_way/urgent_contact が実用的に使われる。3) 新年度疲れの反動で appreciation_for_effort/encouragement の情緒ケア系が継続需要。4) 朝の稼働連絡は greeting_morning + remote_work_report の組み合わせが定着。5) 週末前は meal_invitation と celebration が『小さな回復行動』文脈で伸びる。",
    brand_ideas: "A) 『しとしと気づかい隊』: 雨の日の不調共有と気遣いを主軸にした、やさしい敬語〜砕けた口調のハイブリッド。B) 『即レスこつぶ文鳥』: 1〜6文字中心で返せる超短文特化、ビジネス/私用両対応。C) 『がんばり見てるカエル』: ねぎらい・励ましを毎日使える定番化設計。D) 『雨でも行くよペンギン』: 遅延・移動中連絡を前向きに伝える実務系。",
    line_market_insights: "市場は『感情表現の強さ』より『相手に負担をかけない即時性』が優位。既存人気帯は可愛いだけでは差別化が難しく、用途別（業務即レス/体調共有/ねぎらい）の導線設計が購買理由になりやすい。特にW22は梅雨入り文脈で、天候由来の会話開始スタンプ（雨・傘・だるさ）から本題へ接続できるセット構成が有効。",
    communication_substitute_needs: "『文章を考える余力がない時に、失礼なく・冷たく見えずに返したい』『遅延や体調不良を角を立てず共有したい』『相手の頑張りを短く肯定したい』という代替ニーズが強い。",
    source_url: "https://www.line.me/ja/",
    keywords: %w[LINEスタンプ 週次調査 2026W22 梅雨 気圧不調 即レス ねぎらい 在宅勤務],
    emotions: %w[安心 共感 労り 前向き 連帯感],
    seasons: %w[rainy_season early_summer],
    communication_themes: %w[
      quick_answer
      need_break
      status_busy
      appreciation_for_effort
      encouragement
      greeting_morning
      remote_work_report
      on_the_way
      urgent_contact
      meal_invitation
      celebration
    ],
    attributes: {
      tone: %w[gentle cute neat],
      motif: %w[animal plant tool],
      demographic: %w[age_20s age_30s age_40s business_user unisex],
      setting: %w[remote_work office home with_friends with_family]
    }
  )
end
