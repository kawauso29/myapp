# Linestamp master slug 一覧（seed 作成用の正解辞書）

seed ファイル（`db/seeds/linestamp/imports/pending/*.rb`）で使える slug の一覧。
**ここに無い slug を書くと `ArgumentError: Unknown ... slug` で apply が失敗する。**

> 出典: `db/seeds/linestamp/masters.rb`（`Linestamp::Seeds.call`）。
> master を増減したらこの表も更新すること。CI の `seed-check`（`rake linestamp:validate_imports`）が
> 実際の pending seed を eval して検証するため、ズレや typo はマージ前に赤くなる。

## communication themes（`attach_communication_themes!` / `primary_communication_theme`）

| slug | 名前 | 説明 |
|---|---|---|
| `remote_work_report` | 在宅ワーク報告 | 在宅勤務中の状況を相手に伝える |
| `gratitude` | 感謝 | ありがとうの気持ちを伝える |
| `apology` | 謝罪 | 申し訳なさを和らげて伝える |
| `agreement` | 相槌 | 了解・OK・うん |
| `encouragement` | 励まし | 相手を元気づける |
| `greeting_morning` | おはよう | 朝の挨拶 |
| `greeting_night` | おやすみ | 夜の挨拶 |
| `confirm_meetup` | 待ち合わせ確認 | 今どこ?何時? |
| `on_the_way` | 今行く | 移動中の連絡 |
| `meal_invitation` | 食事の誘い | ご飯行こう |
| `friendly_tease` | 相手をいじる | 軽い冗談・からかい |
| `appreciation_for_effort` | ねぎらい | お疲れさま系 |
| `need_focus` | 集中したい | 今は構わないで |
| `need_break` | 休憩したい | ちょっと休む |
| `quick_answer` | 簡易回答 | はい/いいえ/わかった |
| `urgent_contact` | 緊急連絡 | すぐ確認して系 |
| `status_busy` | 忙しいアピール | 今手が離せない |
| `celebration` | お祝い | おめでとう |

## attribute values（`attach_attribute_values!(brand, {tone:, motif:, demographic:, setting:})`）

軸（axis）は `tone` / `motif` / `demographic` / `setting` の4つ。

### tone（トーン）
`gentle`(ゆるい) `neat`(きっちり) `surreal`(シュール) `cute`(かわいい) `cool`(かっこいい) `stylish`(おしゃれ) `funny`(おもしろい) `elegant`(上品)

### motif（モチーフ）
`animal`(動物) `food`(食べ物) `plant`(植物) `human`(人物) `monster`(モンスター) `abstract`(抽象) `vehicle`(乗り物) `tool`(道具)

### demographic（デモグラフィ）
`age_10s`(10代) `age_20s`(20代) `age_30s`(30代) `age_40s`(40代) `age_50plus`(50代以上) `for_male`(男性向け) `for_female`(女性向け) `unisex`(性別不問) `business_user`(ビジネス層) `student`(学生)

### setting（シーン）
`home`(家庭) `remote_work`(在宅) `office`(オフィス) `with_friends`(友達同士) `with_lover`(恋人) `with_family`(家族) `boss_subordinate`(上司部下) `with_customer`(お客様)

## seed 作成の必須ルール（落とし穴）

- **1 ブランド = 1 ファイル**。`upsert_brand!` → `attach_*` → `create_pack!(... stamps: [8件])` を1ブロックに同梱する。
- **stamp はちょうど 8 件**（初回 Pack）。
- 各 stamp の `primary_communication_theme` は、その Brand に `attach_communication_themes!` した slug の **いずれかと一致**させる。
- `research_slug` は**本番に apply 済みの research** を指すこと。未 apply の research を指すと本番 apply で `Unknown Research slug` になる。
  （CI の `seed-check` は research をスタブ化して構造を検証するので、ここだけは CI を通っても本番で落ちうる点に注意）
- `brand_prompt` / `sheet_prompt` / `prompt` は**埋めない**（after_commit が自動合成する。埋めると合成がスキップされる）。
- `background_color_for_gen` は触らない（モデルで `#3CB371` 固定）。世界観カラーは `primary_color` へ。
- 投入前に `bin/rails linestamp:brand_collision` で既存ブランドとの被りを確認する。

## identity_axes のキー（`upsert_brand!(identity_axes: {...})`・差別化6軸+2）

`silhouette` / `name_origin` / `signature` / `signature_color` / `desire_weakness` / `voice` / `behavior`
（使わない軸は空でよい。空はプロンプトに出ない）
