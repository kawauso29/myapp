# Designer 投入プロンプト設計 — Phase 3 版

> Phase 3(DB-first)実装後、Brand / Series(=Pack)/ Stamp の各レイヤーから Microsoft Designer に投入するプロンプトの設計図。
> `Linestamp::PromptComposer` を Phase 3 のマスタ参照に対応させた。

---

## 全体の流れ

```
[DB の Brand/Pack/Stamp レコード + CT/属性 マスタ]
        ↓
[PromptComposer.compose_brand_prompt / compose_pack_prompt / compose_stamp_prompt]
        ↓
[管理画面の「Designer Kit DL」ボタン]
        ↓
[zip: prompt.txt + 参照画像(brand.base_image / pack.sheet_image)+ README.md]
        ↓
[原田さん が Designer に貼る + 参照画像を添付 → 生成]
        ↓
[生成画像を管理画面に再アップロード]
        ↓
[ChromaKeyProcessor が緑透過 + LINE規格サイズ → processed_image]
```

## 3階層の参照画像チェーン

| レイヤー | 生成する画像 | 参照画像 | 用途 |
|---|---|---|---|
| Brand | `brand.base_image` | なし(キャラ仕様シート単独) | キャラ造形の基準書(12構図+3フォント) |
| Pack(Series) | `pack.sheet_image` | brand.base_image | シリーズ8枚一覧(統一感担保) |
| Stamp | `stamp.raw_image` | brand.base_image + pack.sheet_image | 個別1枚(揺れ防止のため2枚参照) |

## PromptComposer メソッド一覧

| メソッド | 入力 | 出力 |
|---|---|---|
| `compose_brand_prompt(brand)` | Brand レコード + CT + 属性 | base_image 生成用プロンプト |
| `compose_pack_prompt(pack)` | Pack レコード + stamps + CT | sheet_image 生成用プロンプト |
| `compose_stamp_prompt(stamp)` | Stamp レコード + primary_ct | raw_image 生成用プロンプト |

## Brand#attribute_values_by_axis

```ruby
brand.attribute_values_by_axis("tone")   # => [かわいい, おしゃれ]
brand.attribute_values_by_axis("motif")  # => [動物]
brand.attribute_values_by_axis("setting") # => [オフィス]
```

## 過去事故に対する明示的なガード(全プロンプト共通)

| 過去事故 | ガード文言 |
|---|---|
| 白背景で透過時に体が消えた | 「白背景禁止、必ず単色グリーン」 |
| 漢字崩れ | 「漢字は丁寧に正しく。崩れたら再生成、ひらがな逃げ禁止」 |
| 個別書き出しでキャラ揺れ | 「base_image / sheet_image と完全一致、新しい解釈を加えない」 |
| ベース段階でパック8枚生成 | Brand プロンプトに「8枚」「シリーズ」の語を入れない |
| 文字スタイル揺れ | 「フォント仕様は base_image の基準と完全一致」 |

## 実装ファイル

- `app/services/linestamp/prompt_composer.rb`
- `app/models/linestamp/brand.rb` (`attribute_values_by_axis` メソッド)
- `spec/services/linestamp/prompt_composer_spec.rb`
