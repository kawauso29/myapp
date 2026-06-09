#!/usr/bin/env bash
#
# brand_chichinohi_maeguma_seed.sh
# ------------------------------------------------------------------
# LINEスタンプ工房 — ブランド「父の日まえぐまの感謝便」(chichinohi_maeguma)
# Brand + 初回 Pack(8 stamps) を 1 ファイルに同梱して投入する。
# 由来リサーチ: weekly_trends_2026_w24 の brand_idea A。
#
# === なぜ ローカルで ruby を叩かないか ===
#   この環境(原田さんの Win/Git-Bash)には ruby が無い。
#   slug 検証は CI seed-check(rake linestamp:validate_imports)、
#   DB apply は push 後に本番VPS(linestamp:apply_imports)が実行する。
#   → このスクリプトは「seed を書いて push するだけ」。ruby/rails は叩かない。
#
# 冪等。再実行しても seed 内容が同じなら差分なしで push をスキップ。
# 使い方: リポジトリのルート(myapp)で  bash brand_chichinohi_maeguma_seed.sh
# ------------------------------------------------------------------
set -euo pipefail

if [ ! -f Gemfile ] || [ ! -f config/application.rb ]; then
  echo "ERROR: リポジトリのルートで実行してください (myapp で bash brand_chichinohi_maeguma_seed.sh)" >&2
  exit 1
fi

PENDING_DIR="db/seeds/linestamp/imports/pending"
SEED_ID="2026-06-03-001500_brand_chichinohi-maeguma"
SEED_FILE="${PENDING_DIR}/${SEED_ID}.rb"

echo "==> main を origin に同期"
git fetch origin main
git checkout main
git reset --hard origin/main

echo "==> ブランド seed を書き出し: ${SEED_FILE}"
mkdir -p "$PENDING_DIR"
cat > "$SEED_FILE" <<'RUBY'
# frozen_string_literal: true

# ブランド「父の日まえぐまの感謝便」 — 由来: weekly_trends_2026_w24 brand_idea A
# 父の日前週から日常まで、感謝とねぎらいを不器用にまっすぐ"便"にして届けるクマ。
# 既存ブランド(kimochi_kaeru/ameagari_usagi/hirune_alpaca/teru_ham/shittori_rakko)と
# シルエット(封筒を抱えた2.5頭身)・シグネチャ(藍の配達カバン)・色(藍 #1F3A5F)で被らない。

Linestamp::Importer.run(seed_id: "2026-06-03-001500_brand_chichinohi-maeguma") do
  brand = upsert_brand!(
    slug: "chichinohi_maeguma",
    character_name: "まえぐま（マエグマ）",
    series_name: "感謝便",
    persona_name: "不器用だけどまっすぐな配達ぐま",
    concept: "父の日前週から日常まで、感謝とねぎらいを不器用にまっすぐ届けるクマ。気持ちを“便（びん）”にして前もって渡す。",
    target_audience: "20〜40代。家族・職場の双方で感謝やねぎらいを伝えたい層。照れて言葉に詰まりがちな人。business_user も含む。",
    description: "藍色の配達カバンを肩から提げ、両手で封筒を抱えた2.5頭身のずんぐりクマ。渡す前に一度もじもじしてから差し出す。父の日(6/21)前週の“すこし早い感謝”から、日常のおつかれ・ありがとうまでをまっすぐ運ぶ。",
    primary_color: "#1F3A5F",
    research_slug: "weekly_trends_2026_w24",
    two_part_definition: "ただ感謝するクマではない。気持ちを“便”にして前もって届ける配達ぐまだ。",
    character_parts: {
      eyes: "少し垂れた丸い瞳。相手をまっすぐ見つめる",
      mouth: "への字気味だが不器用に微笑む小さめの口",
      ears: "丸く小さめ。左耳に配達タグを付ける",
      body: "2.5頭身のずんぐり体型。ふくよかな胸元で封筒を抱える",
      limbs: "短い手足。両手で藍の封筒を大事に抱える",
      tail: "丸く小さな尻尾",
      collar: "藍色の配達カバンのストラップ（シグネチャ）"
    },
    font_spec: {
      primary: "丸ゴシック太め",
      color: "#1F3A5F",
      outline: "生成りの白フチ"
    },
    tone_axes: {
      warmth: "高（温かい）",
      formality: "中（家族にも職場にも使える）",
      energy: "低〜中（落ち着き）"
    },
    target_axes: {
      age: "20〜40代",
      relationship: "家族×職場の両方",
      usage: "感謝・ねぎらいの前もった一言"
    },
    identity_axes: {
      silhouette: "封筒を両手で抱えた2.5頭身ずんぐり輪郭。黒塗りでも“荷物を抱えた小熊”と分かる（最重要）",
      signature: "藍色の配達カバン＋抱えた封筒",
      signature_color: "#1F3A5F（藍の封筒・カバン）",
      voice: "不器用で言葉少な。でも一言が温かい",
      behavior: "渡す前に一回もじもじしてから差し出す",
      desire_weakness: "感謝を伝えたいのに照れて言葉に詰まる",
      name_origin: "父の日の“前”に届ける＋前のめりな気持ちの“まえ”"
    },
    base_compositions: [
      "封筒を両手で差し出す正面ポーズ",
      "配達カバンから手紙を取り出すポーズ",
      "深くお辞儀して感謝を伝えるポーズ"
    ]
  )

  attach_communication_themes!(brand, %w[
    gratitude
    appreciation_for_effort
    celebration
    encouragement
    greeting_morning
    greeting_night
    agreement
  ])

  attach_attribute_values!(brand, {
    tone: %w[gentle cute neat],
    motif: %w[animal],
    demographic: %w[age_20s age_30s age_40s business_user unisex],
    setting: %w[home with_family office boss_subordinate remote_work]
  })

  create_pack!(
    brand: brand,
    slug: "pack_001",
    series_theme: "感謝便 はじめの一通",
    position: 1,
    layer: "core_work",
    purchase_unit_size: 8,
    world_view: "藍の配達カバンを提げたまえぐまが、感謝とねぎらいを“便”にして届ける。父の日前週の温かい空気を日常まで運ぶ。",
    usage_scenes: %w[家族への感謝 職場のねぎらい 父の日の前ぶり 朝夕の挨拶],
    target_emotions: %w[感謝 安心 労り 温かさ],
    communication_themes: %w[gratitude appreciation_for_effort celebration encouragement greeting_morning greeting_night agreement],
    attributes: {
      tone: %w[gentle cute neat],
      motif: %w[animal],
      demographic: %w[age_20s age_30s age_40s business_user unisex],
      setting: %w[home with_family office boss_subordinate remote_work]
    },
    stamps: [
      {
        label: "いつもありがとう",
        primary_communication_theme: "gratitude",
        communication_themes: %w[gratitude appreciation_for_effort],
        attributes: { tone: %w[gentle], motif: %w[animal], demographic: %w[unisex], setting: %w[home with_family] },
        situation: "日頃の感謝をふと伝えたいとき",
        intent: "重くせず、まっすぐ“ありがとう”を渡す",
        pose_spec: "両手で封筒を差し出し、はにかむ正面",
        props: "藍の封筒",
        usage_scene: "家族・パートナー・同僚への日常の感謝",
        communication_purpose: "感謝を前もって・気軽に伝える",
        search_keywords: %w[ありがとう 感謝 まえぐま 封筒]
      },
      {
        label: "おつかれさま、ひと息どうぞ",
        primary_communication_theme: "appreciation_for_effort",
        communication_themes: %w[appreciation_for_effort need_break],
        attributes: { tone: %w[gentle neat], motif: %w[animal], demographic: %w[business_user], setting: %w[office remote_work] },
        situation: "相手が頑張った直後・退勤前",
        intent: "労いを添えて休息を促す",
        pose_spec: "湯気の立つカップを封筒に添えて差し出す",
        props: "藍の封筒 + 温かいカップ",
        usage_scene: "職場のねぎらい・在宅勤務の労い",
        communication_purpose: "努力をねぎらい安心を返す",
        search_keywords: %w[おつかれさま ねぎらい 休憩 まえぐま]
      },
      {
        label: "父の日、すこし早いけど",
        primary_communication_theme: "celebration",
        communication_themes: %w[celebration gratitude],
        attributes: { tone: %w[gentle cute], motif: %w[animal], demographic: %w[age_30s age_40s], setting: %w[with_family] },
        situation: "父の日(6/21)前週の準備期間",
        intent: "当日より前に、重くしすぎず感謝を前倒しで伝える",
        pose_spec: "リボン付き封筒を抱えて少し照れる",
        props: "リボン付きの藍の封筒",
        usage_scene: "父の日前週の家族チャット",
        communication_purpose: "行事の感謝を前もって軽く渡す",
        search_keywords: %w[父の日 感謝 前週 まえぐま お父さん]
      },
      {
        label: "おはよう、いい一日を",
        primary_communication_theme: "greeting_morning",
        communication_themes: %w[greeting_morning encouragement],
        attributes: { tone: %w[gentle], motif: %w[animal], demographic: %w[unisex], setting: %w[home remote_work] },
        situation: "朝の挨拶",
        intent: "梅雨でも気持ちよく一日を始める後押し",
        pose_spec: "カバンを背負い手を振る朝のポーズ",
        props: "藍の配達カバン",
        usage_scene: "家族・職場の朝の一言",
        communication_purpose: "前向きな朝の挨拶",
        search_keywords: %w[おはよう 朝 まえぐま いい一日]
      },
      {
        label: "おやすみ、また明日",
        primary_communication_theme: "greeting_night",
        communication_themes: %w[greeting_night gratitude],
        attributes: { tone: %w[gentle neat], motif: %w[animal], demographic: %w[unisex], setting: %w[home with_family] },
        situation: "夜の締めの挨拶",
        intent: "一日の終わりに安心を渡す",
        pose_spec: "封筒を枕元に置き、目を細める",
        props: "藍の封筒 + 三日月",
        usage_scene: "就寝前の家族・友人チャット",
        communication_purpose: "穏やかな夜の挨拶",
        search_keywords: %w[おやすみ 夜 また明日 まえぐま]
      },
      {
        label: "その調子、応援してる",
        primary_communication_theme: "encouragement",
        communication_themes: %w[encouragement appreciation_for_effort],
        attributes: { tone: %w[gentle cute], motif: %w[animal], demographic: %w[unisex], setting: %w[office with_family] },
        situation: "相手が頑張っている最中",
        intent: "押しつけず、そっと背中を押す",
        pose_spec: "小さく拳を握りエールを送る",
        props: "応援旗の付いた封筒",
        usage_scene: "仕事・受験・家事を頑張る相手へ",
        communication_purpose: "やさしく励ます",
        search_keywords: %w[応援 がんばれ エール まえぐま]
      },
      {
        label: "了解、まかせて",
        primary_communication_theme: "agreement",
        communication_themes: %w[agreement],
        attributes: { tone: %w[neat gentle], motif: %w[animal], demographic: %w[business_user], setting: %w[office boss_subordinate] },
        situation: "依頼を受けたとき",
        intent: "丁寧さを保った短い快諾",
        pose_spec: "封筒を胸に当て、こくりと頷く",
        props: "藍の封筒",
        usage_scene: "職場の連絡・家族の頼みごと",
        communication_purpose: "信頼感のある同意",
        search_keywords: %w[了解 まかせて 承知 まえぐま]
      },
      {
        label: "感謝、伝えたくて",
        primary_communication_theme: "gratitude",
        communication_themes: %w[gratitude celebration],
        attributes: { tone: %w[gentle cute], motif: %w[animal], demographic: %w[unisex], setting: %w[with_family home] },
        situation: "改まって感謝を伝えたいとき",
        intent: "照れながらも気持ちを言葉にする",
        pose_spec: "封筒を開いて手紙を差し出し深く一礼",
        props: "開いた手紙 + 藍の封筒",
        usage_scene: "記念日・節目の感謝",
        communication_purpose: "気持ちをきちんと届ける",
        search_keywords: %w[感謝 ありがとう 手紙 まえぐま]
      }
    ]
  )
end
RUBY

echo "   seed: 作成 ${SEED_FILE}"

echo "==> commit & push"
git add "$SEED_FILE"
if git diff --cached --quiet; then
  echo "   差分なし — 既に同内容が push 済みのようです。push をスキップ。"
else
  git commit -m "feat(linestamp): ブランド「父の日まえぐまの感謝便」を追加

weekly_trends_2026_w24 brand_idea A 由来。藍の配達カバンを提げた
2.5頭身の配達ぐま chichinohi_maeguma を Brand + 初回 Pack(8 stamps)
同梱で作成。感謝/ねぎらい/父の日前週/挨拶を core CT に据える。
CI seed-check 通過後、本番 linestamp:apply_imports で DB へ反映。"
  git push origin main
  echo "   push 完了。CI(seed-check)通過後、本番VPSが DB に反映します。"
fi

echo
echo "============================================================"
echo " 完了: ブランド「父の日まえぐまの感謝便」(chichinohi_maeguma)"
echo " ▼ 反映状況: GitHub Actions の seed-check / apply_imports を確認"
echo "   反映されると pending/ の seed は applied/ へ移動します"
echo "============================================================"
