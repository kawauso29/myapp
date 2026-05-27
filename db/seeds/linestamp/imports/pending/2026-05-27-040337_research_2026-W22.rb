# frozen_string_literal: true

Linestamp::Importer.run(seed_id: "2026-05-27-040337_research_2026-W22") do
  upsert_research!(
    slug: "linestamp_trends_2026_w22",
    title: "LINEスタンプ週次トレンド調査 2026-W22（感情ニーズ・季節要素・市場動向）",
    body: "2026-W22（5/25〜5/31）は梅雨入り直前の初夏。気温・湿度の変化による体調変動が続き、" \
          "『疲れを短く伝えたい』『気づかいを手軽に受け取りたい』という感情ニーズが高まっている。" \
          "新年度スタートから約2ヶ月が経過し、職場・学校での人間関係がある程度安定した一方、" \
          "累積疲労が表面化しやすい時期。週の後半にかけてリフレッシュ・回復系スタンプの需要が上昇する傾向。" \
          "Z世代〜30代ビジネス層を中心に、ユーモアと共感を両立するスタンプへの関心が継続している。",
    findings: "1) 週中盤（水〜木曜）に『疲れた』『もう無理』系の感情共有スタンプ需要がピーク。" \
              "need_break・status_busy・need_focus が実用的な場面で使われている。\n" \
              "2) 初夏の陽気にもかかわらず気圧変化が続くため、体調不良を笑いに変える『ゆるい不調共有』スタンプが注目。\n" \
              "3) 30〜40代ビジネス層では、上司・部下・取引先に使える『ていねいだけど重くない』表現のニーズが高い。\n" \
              "4) 学生層はグループトークでのリアクション代替（agreement・friendly_tease）が主流で、1〜3文字相当のスタンプが好まれる。\n" \
              "5) 夕方〜夜間帯に greeting_night・encouragement・appreciation_for_effort のセット使いが増加。\n" \
              "6) meal_invitation・confirm_meetup は週末前（金曜日）に集中して使用される傾向。\n" \
              "7) apology系は丁寧すぎず・軽すぎない中間トーンが市場の空白になっており、差別化余地あり。",
    brand_ideas: "A) 『つかれたわにさん』: 疲労感を愛嬌で包む爬虫類キャラ。need_break・status_busy・quick_answer を主軸に、" \
                 "ビジネス〜友人グループまで使い回せる万能ゆるキャラ。トーンはgentle+funny。\n" \
                 "B) 『ていねい小熊』: boss_subordinate・with_customer 文脈で使える、品のあるかわいい小熊。" \
                 "apology・gratitude・agreement・encouragement を丁寧に表現。トーンはneat+cute。\n" \
                 "C) 『ちょっとまってカタツムリ』: 初夏・梅雨の季節感と『今ちょっと無理です』感情を融合。" \
                 "need_focus・on_the_way・status_busy のフレーズを可愛く逃げ口上として使えるシリーズ。\n" \
                 "D) 『ばっちりペア敬語セット』: 友人〜職場まで対応する2パターン収録型。" \
                 "メッセージを送る側・受け取る側の両視点をカバーし、agreement・quick_answer・celebrationを充実。",
    line_market_insights: "2026年初夏のLINEスタンプ市場は以下の3軸が競争優位を決める。\n" \
                          "① 用途の明快さ: 『この場面で使えばいい』と直感できるラベル設計が購買率を高める。\n" \
                          "② 感情の温度感: 熱すぎず・冷たすぎない『中温感情』（共感・ねぎらい・軽いユーモア）が幅広い場面で使われる。\n" \
                          "③ 季節限定性の排除: 梅雨・初夏の要素を入れつつも通年使える構成にすることで、" \
                          "ロングテール収益を確保できる。人気ランキング上位は動物モチーフ×ゆるトーンが依然強く、" \
                          "この組み合わせに『シーン特化』の軸を加えると差別化できる。" \
                          "また、スタンプショップでのキーワード検索では『疲れた』『ありがとう』『了解』が恒常的に上位で、" \
                          "これらを自然に含む一言フレーズスタンプの市場は飽和していない。",
    communication_substitute_needs: "『長い謝罪文を送る前に、まず軽く詫びを入れたい』" \
                                    "『了解・承知の返信を一言で済ませたいが、冷たく見られたくない』" \
                                    "『夜遅くの連絡で、相手の迷惑になっていないか気になる場面でのクッション』" \
                                    "『グループトークでリアクションしたいが、既読スルーは避けたい』" \
                                    "『疲れを表明しながら場の空気を重くしたくない』というニーズが特に強い。",
    source_url: "https://store.line.me/home/ja",
    keywords: %w[LINEスタンプ 週次調査 2026W22 初夏 梅雨前 疲労共有 感情ニーズ ゆるキャラ ビジネス敬語 Z世代],
    emotions: %w[共感 安心 ユーモア ねぎらい 連帯感 リフレッシュ],
    seasons: %w[early_summer rainy_season],
    communication_themes: %w[
      need_break
      status_busy
      need_focus
      quick_answer
      agreement
      apology
      gratitude
      appreciation_for_effort
      encouragement
      greeting_night
      on_the_way
      confirm_meetup
      meal_invitation
      friendly_tease
      celebration
    ],
    attributes: {
      tone: %w[gentle cute funny neat],
      motif: %w[animal],
      demographic: %w[age_20s age_30s age_40s student business_user unisex],
      setting: %w[remote_work office home with_friends boss_subordinate with_customer]
    }
  )
end
