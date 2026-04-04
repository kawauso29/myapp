# Family member seed data
# Keyed by AI profile name → list of family members
# birth_year is used to compute age dynamically each year
SEED_FAMILY_MEMBERS = {
  # ── parent_young (幼い子ども 0〜6歳) ──────────────────────────────
  "加藤マイ" => [
    { name: "ヒロキ", relationship: :partner, birth_year: 1983, notes: "会社員・土日は育児積極的" },
    { name: "リン",   relationship: :child,   birth_year: 2023, notes: "保育園に通っている" },
  ],
  "三浦ケイスケ" => [
    { name: "ユキコ", relationship: :partner, birth_year: 1986, notes: "パートタイム勤務" },
    { name: "ケン",   relationship: :child,   birth_year: 2021, notes: "保育園の年長さん" },
    { name: "アユ",   relationship: :child,   birth_year: 2024, notes: "まだ1歳、やんちゃ盛り" },
  ],
  "内田リュウジ" => [
    { name: "マリコ", relationship: :partner, birth_year: 1982, notes: "居酒屋の経理を手伝っている" },
    { name: "ショウ", relationship: :child,   birth_year: 2021, notes: "保育園の年長さん" },
  ],
  "田村ヒデキ" => [
    { name: "サオリ", relationship: :partner, birth_year: 1984, notes: "看護師" },
    { name: "ナナ",   relationship: :child,   birth_year: 2022, notes: "保育園に通っている" },
    { name: "ソウ",   relationship: :child,   birth_year: 2024, notes: "まだ2歳" },
  ],

  # ── parent_school (小中学生) ────────────────────────────────────────
  "鈴木タカシ" => [
    { name: "カオリ",   relationship: :partner, birth_year: 1982, notes: "専業主婦" },
    { name: "ヨウタ",   relationship: :child,   birth_year: 2015, notes: "小学5年生・少年野球チームに入っている" },
    { name: "アカリ",   relationship: :child,   birth_year: 2018, notes: "小学3年生・ピアノを習っている" },
  ],
  "吉田サエ" => [
    { name: "コウスケ", relationship: :partner, birth_year: 1980, notes: "地元の建設会社勤務" },
    { name: "ハルト",   relationship: :child,   birth_year: 2016, notes: "小学4年生・サッカーが好き" },
    { name: "ユイ",     relationship: :child,   birth_year: 2019, notes: "小学1年生・入学したばかり" },
  ],
  "近藤マキ" => [
    { name: "ノブオ",   relationship: :partner, birth_year: 1977, notes: "建設会社の現場監督" },
    { name: "ユウキ",   relationship: :child,   birth_year: 2012, notes: "中学2年生・反抗期まっさかり" },
  ],
  "久保田ショウ" => [
    { name: "アヤ",     relationship: :partner, birth_year: 1985, notes: "専業主婦" },
    { name: "リョウスケ", relationship: :child, birth_year: 2014, notes: "小学6年生・受験を考えている" },
    { name: "ミオ",     relationship: :child,   birth_year: 2017, notes: "小学3年生・習字を習っている" },
  ],
  "宮田コウジ" => [
    { name: "ヨシコ",   relationship: :partner, birth_year: 1979, notes: "パートで近所のスーパー勤務" },
    { name: "タイヨウ", relationship: :child,   birth_year: 2013, notes: "中学1年生・ゲーム好き" },
  ],

  # ── parent_adult (成人した子ども) ──────────────────────────────────
  "伊藤アキラ" => [
    { name: "フミコ",   relationship: :partner, birth_year: 1973, notes: "定食屋を一緒に切り盛りしている" },
    { name: "ヒカリ",   relationship: :child,   birth_year: 2000, notes: "結婚して東京在住・孫はまだ" },
    { name: "タロウ",   relationship: :child,   birth_year: 2003, notes: "就職して仙台で一人暮らし" },
  ],
  "藤田マサル" => [
    { name: "ケイコ",   relationship: :partner, birth_year: 1977, notes: "パートタイム勤務" },
    { name: "サヤ",     relationship: :child,   birth_year: 1999, notes: "結婚して神奈川在住" },
    { name: "ケイタ",   relationship: :child,   birth_year: 2002, notes: "大学院生" },
  ],
  "島田コウヘイ" => [
    { name: "ヨウコ",   relationship: :partner, birth_year: 1975, notes: "大学の事務職" },
    { name: "エリ",     relationship: :child,   birth_year: 2001, notes: "就職3年目・商社勤務" },
    { name: "ユウスケ", relationship: :child,   birth_year: 2004, notes: "大学4年生・就活中" },
  ],

  # ── senior (シニア・パートナーのみ) ────────────────────────────────
  "村上シンジ" => [
    { name: "トシコ", relationship: :partner, birth_year: 1964, notes: "一緒に農業をやっている・料理上手" },
  ],
  "野村サチコ" => [
    { name: "ノリオ", relationship: :partner, birth_year: 1957, notes: "定年退職済み・家庭菜園が趣味" },
  ],
}.freeze
