# frozen_string_literal: true

Linestamp::Importer.run(seed_id: "2026-06-01-231033_pack_tsuyu_reply_care") do
  brand = Linestamp::Brand.find_by!(slug: "teru_ham")

  create_pack!(
    brand: brand,
    slug: "tsuyu_reply_care",
    series_theme: "梅雨どき秒レスいたわり",
    position: 2,
    layer: "core_work",
    purchase_unit_size: 8,
    world_view: "低気圧で余裕がない日も、短文で角を立てずに状況共有できる",
    usage_scenes: %w[remote_work office home],
    target_emotions: %w[安心 共感 気づかい],
    communication_themes: %w[quick_answer agreement status_busy urgent_contact apology gratitude need_break appreciation_for_effort],
    attributes: {
      tone: %w[gentle cute],
      setting: %w[remote_work office home]
    },
    stamps: [
      {
        label: "みてます",
        primary_communication_theme: "quick_answer",
        communication_themes: %w[quick_answer],
        attributes: { tone: %w[gentle], setting: %w[remote_work office] },
        situation: "通知だけ先に確認したとき",
        intent: "既読だけでも安心させる",
        search_keywords: %w[確認 既読 了解]
      },
      {
        label: "それです",
        primary_communication_theme: "agreement",
        communication_themes: %w[agreement],
        attributes: { tone: %w[cute gentle], setting: %w[office with_friends] },
        situation: "相手の提案に賛成したいとき",
        intent: "短文で同意を返す",
        search_keywords: %w[同意 賛成 それな]
      },
      {
        label: "いま手一杯",
        primary_communication_theme: "status_busy",
        communication_themes: %w[status_busy],
        attributes: { tone: %w[gentle], setting: %w[remote_work office] },
        situation: "作業が立て込んでいるとき",
        intent: "忙しさを穏やかに共有する",
        search_keywords: %w[多忙 忙しい 作業中]
      },
      {
        label: "至急おねがい",
        primary_communication_theme: "urgent_contact",
        communication_themes: %w[urgent_contact],
        attributes: { tone: %w[gentle], setting: %w[office remote_work] },
        situation: "今すぐ確認してほしいとき",
        intent: "緊急度を明確に伝える",
        search_keywords: %w[至急 緊急 確認]
      },
      {
        label: "遅れてます",
        primary_communication_theme: "apology",
        communication_themes: %w[apology status_busy],
        attributes: { tone: %w[gentle], setting: %w[office home] },
        situation: "返信や対応が遅れたとき",
        intent: "まず一言で謝意を示す",
        search_keywords: %w[遅延 謝罪 ごめん]
      },
      {
        label: "助かります",
        primary_communication_theme: "gratitude",
        communication_themes: %w[gratitude],
        attributes: { tone: %w[gentle cute], setting: %w[office remote_work] },
        situation: "フォローしてもらったとき",
        intent: "感謝を即レスする",
        search_keywords: %w[感謝 ありがとう 助かる]
      },
      {
        label: "5分休みます",
        primary_communication_theme: "need_break",
        communication_themes: %w[need_break status_busy],
        attributes: { tone: %w[gentle], setting: %w[remote_work home office] },
        situation: "短い離席を伝えるとき",
        intent: "休憩を角を立てず共有する",
        search_keywords: %w[休憩 離席 中抜け]
      },
      {
        label: "おつかれです",
        primary_communication_theme: "appreciation_for_effort",
        communication_themes: %w[appreciation_for_effort],
        attributes: { tone: %w[gentle cute], setting: %w[office remote_work with_friends] },
        situation: "作業終わりに声をかけるとき",
        intent: "ねぎらいで気持ちを整える",
        search_keywords: %w[おつかれ ねぎらい 退勤]
      }
    ]
  )
end
