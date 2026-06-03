# frozen_string_literal: true

# LINEスタンプ週次調査 2026-W24
# 起点: 梅雨中盤のだるさケア + 父の日前週の感謝準備 + 初夏の生活リズム整え。
# brand_ideas は後続のブランド企画が消費する素材。A〜D の具体案を用意した。

Linestamp::Importer.run(seed_id: "2026-06-03-001200_research_2026-W24") do
  upsert_research!(
    slug: "weekly_trends_2026_w24",
    title: "LINEスタンプ週次調査 2026-W24（梅雨中盤のだるさケア・父の日前週の感謝・初夏の生活リズム）",
    body: "2026-W24（6/8〜6/14）は梅雨が中盤に入り、長雨と気圧変動による『だるさ・気分の重さ』の共有が定着する週。加えて翌週の父の日（6/21）を控え、日頃の感謝やねぎらいを“前もって・軽く”伝えたい需要が立ち上がる。平日は在宅/出社いずれも短文の即レスと体調気づかいが中心、週末手前は衣替え後の初夏の身支度や食の誘いなど『小さな生活リズム回復』の導線が伸びる。天候・季節の一言を入口に、感謝や実務連絡へ自然につなげる設計が有効。",
    findings: "1) 梅雨中盤は need_break/status_busy/quick_answer の『角を立てない離席・即レス』が継続して高需要。2) 低気圧やだるさの共有には appreciation_for_effort/gratitude/encouragement を添えると既読スルーを避けやすい。3) 父の日前週は celebration/gratitude を“重くしすぎない”短文で前倒しに使う動きが出る（当日より準備期間に分散）。4) 朝夕の挨拶は greeting_morning/greeting_night に季節文脈（雨・蒸し暑い・明るい夕方）を付けると反応が良い。5) 衣替え後の初夏は meal_invitation/confirm_meetup/on_the_way の『軽い外出・食の誘い』が週末手前に増える。",
    brand_ideas: "A) 『父の日まえぐまの感謝便』: 父の日前週から日常まで、感謝とねぎらいを不器用にまっすぐ伝えるクマ。2.5頭身・丸く大きめの輪郭が黒塗りでも分かる。celebration/gratitude/appreciation_for_effort 中心。 B) 『あじさいカタツムリの“ゆっくりでいい”』: 急かさず自分のペースを肯定する梅雨モチーフ。横長の渦巻き殻が一目で識別できる。status_busy/need_break/quick_answer/agreement 中心。 C) 『初夏したくリス』: 衣替え・身支度・生活リズム整えを前向きに後押し。大きな尾と丸ほっぺのシルエット。greeting_morning/encouragement/meal_invitation 中心。 D) 『夏至よみどりインコ』: 一年で一番明るい夕方を楽しむ夜寄りキャラ。小柄＋冠羽が識別ポイント。greeting_night/celebration/meal_invitation 中心。",
    line_market_insights: "市場は『見た目のかわいさ単体』より『どの場面で使うか即決できる用途設計』が優位。梅雨期は天候起点の一言→状況共有→気づかい返答の3段会話に乗るセットが再利用されやすく、父の日のような行事は当日単発より“前週からの準備会話”に分散して使われる。ビジネス層は丁寧さを保った短文、私用は共感を先に置く短文を好み、同一キャラで両文脈を跨げる設計が差別化要因になる。",
    communication_substitute_needs: "『だるくて長文を打つ余力がない時でも、冷たく見せずに状況を共有したい』『父の日の感謝を、照れずに重くしすぎず先に伝えたい』『相手のしんどさに即反応して安心を返したい』『初夏の外出や食事を、軽いノリで誘いたい』という代替ニーズが強い。",
    source_url: "https://www.line.me/ja/",
    keywords: %w[LINEスタンプ 週次調査 2026W24 梅雨中盤 だるさケア 父の日前週 初夏 短文気づかい 生活リズム],
    emotions: %w[感謝 安心 共感 労り 前向き],
    seasons: %w[rainy_season early_summer],
    communication_themes: %w[
      celebration
      gratitude
      appreciation_for_effort
      encouragement
      greeting_morning
      greeting_night
      need_break
      status_busy
      quick_answer
      agreement
      meal_invitation
      confirm_meetup
      on_the_way
    ],
    attributes: {
      tone: %w[gentle cute neat],
      motif: %w[animal plant food],
      demographic: %w[age_20s age_30s age_40s business_user unisex],
      setting: %w[home remote_work office with_family with_friends]
    }
  )
end
