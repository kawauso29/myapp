# 02. DB スキーマ仕様

## マイグレーションファイル一覧

連番タイムスタンプで以下を作成(`rails g migration` で雛形)。

1. `create_linestamp_researches`
2. `create_linestamp_brands`
3. `create_linestamp_packs`
4. `create_linestamp_stamps`
5. `create_linestamp_submissions`
6. `add_admin_to_users` (12 A-1 参照、User#admin? 未存在なら)
7. `add_active_storage_attachments`(ActiveStorage 未導入なら)

**作成しないテーブル**: `linestamp_generations`(SD 試行履歴用だった、SD ルートを採用しないため不要)

---

## 1. linestamp_researches

```ruby
class CreateLinestampResearches < ActiveRecord::Migration[8.1]
  def change
    create_table :linestamp_researches do |t|
      t.string  :slug,              null: false, comment: "2026-W21 形式の週ID"
      t.text    :brief,             null: false, comment: "調査依頼テキスト(原田さん→Copilot)"
      t.text    :findings_md,       null: false, comment: "調査結果本文 (md)"
      t.jsonb   :trends,            null: false, default: {}, comment: "抽出キーワード/季節/感情/世代"
      t.string  :source_path,                    comment: "research/{slug}/findings.md"
      t.timestamps

      t.index :slug, unique: true
    end
  end
end
```

## 2. linestamp_brands

```ruby
class CreateLinestampBrands < ActiveRecord::Migration[8.1]
  def change
    create_table :linestamp_brands do |t|
      t.references :research, foreign_key: { to_table: :linestamp_researches }
      t.string  :slug,             null: false, comment: "英数スネーク、例: nemuinu"
      t.string  :series_name,      null: false, comment: "シリーズ名(キャラの世界観名)"
      t.string  :character_name,   null: false, comment: "キャラ名"
      t.text    :brand_theme_md,   null: false, comment: "01_brand_theme.md 全文"
      t.text    :base_md,          null: false, comment: "02_base.md 全文"
      t.text    :base_prompt,                   comment: "合成済みSDプロンプト"
      t.string  :state,            null: false, default: "planned", comment: "AASM state"
      t.jsonb   :metadata,         null: false, default: {}, comment: "negative_prompt, model, lora設定等"
      t.text    :error_message
      t.timestamps

      t.index :slug, unique: true
      t.index :state
    end
  end
end
```

**ActiveStorage 添付** (別マイグレーション or `bin/rails active_storage:install` 実行済前提):
- `brand.base_image` — ブランドベース画像(キャラ標準姿)

## 3. linestamp_packs

```ruby
class CreateLinestampPacks < ActiveRecord::Migration[8.1]
  def change
    create_table :linestamp_packs do |t|
      t.references :brand, null: false, foreign_key: { to_table: :linestamp_brands }
      t.string  :slug,           null: false, comment: "pack_001, dreamy_sleep 等"
      t.string  :series_theme,   null: false, comment: "シリーズテーマ名(例: 在宅ワーク基本)"
      t.text    :pack_md,        null: false, comment: "03_stamp_pack.md 全文"
      t.text    :sheet_prompt,                comment: "シリーズベース画像(一覧)生成用プロンプト"
      t.string  :layer,                       comment: "core_work / dream / weekend 等"
      t.string  :state,          null: false, default: "planned", comment: "AASM state"
      t.boolean :approved,       null: false, default: false, comment: "原田さんの承認チェック"
      t.datetime :approved_at
      t.jsonb   :metadata,       null: false, default: {}
      t.text    :error_message
      t.timestamps

      t.index [:brand_id, :slug], unique: true
      t.index :state
      t.index :approved
    end
  end
end
```

**ActiveStorage 添付**:
- `pack.sheet_image` — シリーズベース画像(8枚一覧シート)

## 4. linestamp_stamps

```ruby
class CreateLinestampStamps < ActiveRecord::Migration[8.1]
  def change
    create_table :linestamp_stamps do |t|
      t.references :pack, null: false, foreign_key: { to_table: :linestamp_packs }
      t.integer :number,             null: false, comment: "1..8 (パック内連番)"
      t.string  :label,              null: false, comment: "「いま仕事中だよ」等"
      t.text    :situation,          comment: "シチュエーション説明"
      t.text    :prompt,             comment: "Designer 用に合成済みプロンプト"
      t.string  :state,              null: false, default: "planned"
      t.text    :error_message
      t.timestamps

      t.index [:pack_id, :number], unique: true
      t.index :state
    end
  end
end
```

**ActiveStorage 添付**:
- `stamp.raw_image` — グリーンバック原画
- `stamp.processed_image` — LINE規格透過済PNG

## 5. linestamp_submissions

```ruby
class CreateLinestampSubmissions < ActiveRecord::Migration[8.1]
  def change
    create_table :linestamp_submissions do |t|
      t.references :pack, null: false, foreign_key: { to_table: :linestamp_packs }
      t.string  :line_pack_id, comment: "LINE側のスタンプセットID"
      t.string  :state,        null: false, default: "drafting", comment: "drafting / submitted / approved / rejected / selling"
      t.datetime :submitted_at
      t.datetime :approved_at
      t.text    :review_note,  comment: "LINE審査からのコメント"
      t.timestamps

      t.index :state
    end
  end
end
```

---

## 状態(state)の取りうる値(参考)

| テーブル | 取りうる状態 |
|---|---|
| brands | planned / prompt_ready / base_ready / error |
| packs | planned / prompt_ready / sheet_ready / stamps_generating / complete / error |
| stamps | planned / prompt_ready / raw_ready / processed / error |
| submissions | drafting / submitted / approved / rejected / selling |

**SD 削除に伴い、中間状態(base_generating / sheet_generating / image_generating / processing)は不要になりました。**

詳細な遷移は `03_MODELS.md` 参照。

---

## ER 図(簡易)

```
Research 1 ── * Brand 1 ── * Pack 1 ── * Stamp
                              │
                              └── 1 Submission(任意)
```

`Generation` テーブル(SD試行履歴用)は削除済み。

---

## seed の取り扱い

`db/seeds.rb` には書かず、専用 rake タスクで:

```ruby
# lib/tasks/linestamp.rake
namespace :linestamp do
  desc "Sync brand_sources/ md files to DB"
  task sync: :environment do
    Linestamp::BrandSourcesSyncer.new.call
  end

  desc "Seed nemuinu from existing assets"
  task seed_nemuinu: :environment do
    Linestamp::Seeders::Nemuinu.new.call
  end
end
```

詳細は `04_SERVICES.md` (BrandSourcesSyncer) 参照。
