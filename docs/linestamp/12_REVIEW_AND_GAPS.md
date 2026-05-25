# 12. セルフレビュー + 抜け漏れ補強

設計書全体を見直して見つけた **抜け / 弱点 / 修正点** をここに集約。
Copilot Coding Agent はこのファイルも必読。

---

## A. 既存 myapp との統合周り

### A-1. AdminController と admin ロール

**問題**: 既存 myapp に `AdminController` や `User#admin?` がない可能性。

**対策**: 以下を実装(未存在のみ):

```ruby
# db/migrate/YYYYMMDDHHMMSS_add_admin_to_users.rb
class AddAdminToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :admin, :boolean, null: false, default: false
    add_index :users, :admin
  end
end
```

```ruby
# app/controllers/admin_controller.rb
class AdminController < ApplicationController
  layout "admin"
  before_action :authenticate_user!
  before_action :require_admin

  private

  def require_admin
    redirect_to root_path, alert: "管理者権限が必要です" unless current_user&.admin?
  end
end
```

初期 admin ユーザー作成は `db/seeds.rb` または手動 console:
```ruby
User.find_by(email: "k.harada@arts-net.co.jp").update!(admin: true)
```

### A-2. Rails API mode で ERB views を許可

**問題**: myapp は API mode (`config.api_only = true`)。ERB管理画面は session ベース。

**対策**: `Admin::*` 名前空間下のコントローラだけ session + ERB を有効化:

```ruby
# app/controllers/admin_controller.rb
class AdminController < ApplicationController
  # API mode をオーバーライド
  include ActionController::Cookies
  include ActionController::Flash
  include ActionView::Layouts
  protect_from_forgery with: :exception

  layout "admin"
  before_action :authenticate_user!
  before_action :require_admin
  # ...
end
```

または `application.rb` で `config.api_only = false` に変更し、API側で `ActionController::API` を明示継承する手も。**既存コントローラを壊さないため後者は非推奨。**

### A-3. Devise セッション有効化

**問題**: API mode + JWT 中心の構成だと session_store 未設定の可能性。

**対策**: `config/initializers/session_store.rb`(未存在なら):

```ruby
Rails.application.config.session_store :cookie_store, key: "_myapp_admin_session"
Rails.application.config.middleware.use ActionDispatch::Cookies
Rails.application.config.middleware.use Rails.application.config.session_store, Rails.application.config.session_options
```

Devise の routes は session ベースで動作するよう `:database_authenticatable` が有効か確認。

---

## B. 状態機械の安全性

### B-1. Pack#complete_all のガード補強

**問題**: `pack.stamps.all?(&:processed?)` だと **stamps が0件でも true** になる(空配列の vacuous true)。

**修正**: `03_MODELS.md` の Pack AASM:

```ruby
event :complete_all do
  transitions from: :stamps_generating, to: :complete,
              guard: ->(pack) { pack.stamps.any? && pack.stamps.all?(&:processed?) }
end
```

### B-2. Stamp 失敗時の Pack の扱い

**問題**: 8枚中1枚でも `error` だと `complete_all` が永遠に発火しない。

**対策**: ステート `partial_complete` を Pack に追加 or 手動介入を期待:

```ruby
# 簡易: error stamp を再生成 or ignored にする運用
# error stamp は管理画面の「再生成」で revive される

# 補助メソッド
def all_stamps_resolved?
  stamps.any? && stamps.all? { |s| s.processed? || s.state == "error" }
end
```

ダッシュボードで「Pack #XX: 7/8 processed, 1 error」を見せる UI を入れる。

### B-3. Submission 自動作成

**問題**: Pack が `complete` になっても Submission レコードが自動作成されない。

**対策**: AASM の after コールバック:

```ruby
event :complete_all, after: :ensure_draft_submission do
  transitions from: :stamps_generating, to: :complete,
              guard: ->(pack) { pack.stamps.any? && pack.stamps.all?(&:processed?) }
end

private

def ensure_draft_submission
  submissions.create!(state: "drafting") unless submissions.exists?
end
```

### B-4. AASM `whiny_transitions: false` で失敗を見逃す

**問題**: `false` だとガード失敗で例外が出ない、サイレント。

**対策**: Job 側で `unless pack.may_xxx?` を必ずチェックして失敗時はログ+Slack通知:

```ruby
unless pack.may_start_sheet_generation?
  Linestamp::SlackNotifier.notify(text: "⚠️ Pack ##{pack.id}: state遷移失敗 (#{pack.state})")
  return
end
```

---

## C. パフォーマンス・並列性

### C-1. ~~Sidekiq job timeout~~

**SD 削除のため不要**。残るジョブはプロンプト合成(数秒)と mini_magick(数秒)のみ。

### C-2. DB connection pool

**問題**: Sidekiq concurrency 5 + Puma worker → 同時接続が pool を超える。

**修正**: `config/database.yml`:

```yaml
default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 20 } %>
```

### C-3. ~~linestamp_generate キューの concurrency~~

**SD 削除のため不要**。`linestamp_generate` キュー自体が存在しない。

### C-4. ~~SD サーバ未起動時のリトライ~~

**SD 削除のため不要**。

---

## D. LINE 申請規格カバー

### D-1. 追加で必要な画像(現状未対応)

LINE スタンプ申請には main image / tab image も必要:

| 画像種別 | サイズ | 用途 |
|---|---|---|
| メインスタンプ | 370×320 | 個別スタンプ8枚(✓ 実装済) |
| **メイン画像** | 240×240 | パック代表画像(❌ 未実装) |
| **タブ画像** | 96×74 | カテゴリタブ用(❌ 未実装) |

**対策**: Future work として `ChromaKeyProcessor` を拡張、Pack 単位で main_image / tab_image を生成する Job を追加(本リリースには含めない、TODO 記載のみ)。

`Linestamp::Pack` に `has_one_attached :main_image` / `:tab_image` を最初から追加しておくと将来楽。

### D-2. 申請ファイル命名規約

LINE 申請時は `01.png ... 08.png` 連番。現状 `stamp_01_label.png` で保存。

**対策**: 申請用にリネームする「エクスポート」機能を管理画面に追加(zip ダウンロード):

```ruby
# Admin::Linestamp::PacksController に追加
def export_for_line
  @pack = ::Linestamp::Pack.find(params[:id])
  send_data ::Linestamp::LineExporter.new(@pack).zip,
            filename: "#{@pack.brand.slug}_#{@pack.slug}.zip",
            type: "application/zip"
end
```

Service `Linestamp::LineExporter` は各 stamp.processed_image を `01.png` `02.png`... としてzip化。

---

## E. 運用観測性

### E-1. Sidekiq Web UI mount

**追加**: routes.rb:

```ruby
require "sidekiq/web"

authenticate :user, ->(user) { user.admin? } do
  mount Sidekiq::Web => "/admin/sidekiq"
end
```

### E-2. 構造化ログ

**推奨**: 各 Job が `Rails.logger.tagged("Linestamp")` でログを出す。grep 容易。

```ruby
def perform(brand_id)
  Rails.logger.tagged("Linestamp", "Brand[#{brand_id}]") do
    # ...
  end
end
```

### E-3. エラー Slack 通知

**追加**: ApplicationJob で rescue + Slack 通知:

```ruby
# app/jobs/application_job.rb (既存に追加)
rescue_from(StandardError) do |exception|
  if self.class.name.start_with?("Linestamp::")
    Linestamp::SlackNotifier.notify(
      text: "🚨 Job失敗: #{self.class.name}\n#{exception.message[0..500]}"
    )
  end
  raise
end
```

---

## F. データモデル補強

### F-1. Pack に承認者ID

**問題**: 「誰が承認したか」が分からない(approved_at だけだと監査不能)。

**修正**: マイグレーション追加:

```ruby
add_reference :linestamp_packs, :approver, foreign_key: { to_table: :users }
```

```ruby
# Pack model
belongs_to :approver, class_name: "User", optional: true

def approve_by!(user)
  update!(approved: true, approved_at: Time.current, approver: user)
end
```

```ruby
# PacksController
def approve
  @pack.approve_by!(current_user)
  # ...
end
```

### F-2. Pack に main_image / tab_image(将来用)

```ruby
# app/models/linestamp/pack.rb
has_one_attached :sheet_image       # 8枚一覧(実装済み)
has_one_attached :main_image        # 240x240 (Phase 後で)
has_one_attached :tab_image         # 96x74 (Phase 後で)
```

DB マイグレーション変更なし(ActiveStorage は別テーブル)。

### F-3. Generation の image 保持

**選択**: 失敗 generation の image を残すか? 残すならSizeが膨らむ。

**結論(v1)**: 残さない。`status: "failed"` の rejection_reason だけ記録、画像は捨てる。

---

## G. 漏れていた gem / 設定

### G-1. Kaminari(ページネーション)

```ruby
gem 'kaminari'
```

`bundle install` 後、admin views で `<%= paginate @packs %>` が使える。

### G-2. Bootstrap or Tailwind?

ERB 管理画面に最低限のスタイル。**Tailwind CDN**(他依存なし)を採用。

```erb
<!-- app/views/layouts/admin.html.erb -->
<script src="https://cdn.tailwindcss.com"></script>
```

### G-3. ActiveStorage の保存先

**v1**: local fs(デフォルト)
**将来**: S3 or Cloudflare R2

```yaml
# config/storage.yml
local:
  service: Disk
  root: <%= Rails.root.join("storage") %>
```

`storage/` が git で無視されることを `.gitignore` で確認。

---

## H. テスト fixtures

### H-1. nemuinu の緑背景画像をテスト fixture として配置

**Issue #9 (ChromaKeyProcessor)** のテストには緑背景の入力画像が必要。

**対策**: `spec/fixtures/linestamp/stamp_01_green.png` に nemuinu の `stamp_01.png` を配置。元データは原田さんから提供される `nemuinu_full_handover_bundle.zip` → `linestamp/ねむ犬/pack_001/stamp_01.png`。

**ファイルサイズが大きい場合**: git LFS、または最小サンプル画像を別途用意。

---

## I. ねむ犬 seed の現実的な扱い

### I-1. 既存 base.png は引継ぎ画像から

```bash
# repo に置く
cp nemuinu_handover_bundle/base.png brand_sources/nemuinu/base.png
cp nemuinu_handover_bundle/pack_001/output/*.png brand_sources/nemuinu/packs/pack_001/output/
```

### I-2. Seeders::Nemuinu で attach

`04_SERVICES.md` の Seeder コードは正しい。ただし以下確認:
- パス存在チェック追加(画像が無いケースでも seed 成功するように)
- 既存 attach があれば再 attach しない(冪等)

```ruby
brand.base_image.attach(io: File.open(base_path), filename: "base.png") if base_path.exist? && !brand.base_image.attached?
```

---

## J. Self-hosted runner の labels

### J-1. workflow `runs-on` の指定

**現状**: `runs-on: self-hosted` のみ。

**推奨**: 専用ラベル付与:

```yaml
runs-on: [self-hosted, linestamp]
```

セルフホストランナー設定時に `--labels linestamp` を追加。他用途のランナーと混ざらない。

---

## K. その他 細々

### K-1. routes.rb のドラフト

11_ISSUES_BACKLOG にあるが、最終形を再掲:

```ruby
# config/routes.rb
Rails.application.routes.draw do
  # 既存routes...

  require "sidekiq/web"
  authenticate :user, ->(u) { u.admin? } do
    mount Sidekiq::Web => "/admin/sidekiq"

    namespace :admin do
      namespace :linestamp do
        root to: "dashboard#index"
        resources :brands, only: %i[index show]
        resources :packs do
          member do
            patch :approve
            patch :unapprove
            get   :export_for_line
          end
          resources :stamps, only: %i[index show] do
            member { patch :retry }
          end
        end
        resources :researches, only: %i[index show]
        resources :submissions, only: %i[index show update] do
          member do
            patch :submit
            patch :mark_approved
            patch :mark_rejected
          end
        end
      end
    end
  end

  post "/webhooks/linestamp/sync", to: "linestamp/webhooks#sync"
end
```

### K-2. ~~SD model 設定~~

**SD 削除のため不要**。

### K-3. 並列ファイル書き込み

`scripts/transparency_pipeline.py` を捨てて mini_magick 一本化したので、Python 関連の docs (`scripts/transparency_pipeline.py`) は **削除する**。

---

## まとめ: 補強チェックリスト(SD削除後)

実装時に必ず適用する事項:

- [ ] AdminController + User#admin? 確認(A-1)
- [ ] API mode で ERB を有効化(A-2)
- [ ] Devise session 設定確認(A-3)
- [ ] Pack#complete_all ガードに `stamps.any?` 追加(B-1)
- [ ] Submission 自動作成(B-3)
- [ ] DB pool 20+(C-2)
- [ ] Pack に approver_id 追加(F-1)
- [ ] Pack に main_image / tab_image 追加(F-2)
- [ ] kaminari gem 追加(G-1)
- [ ] Tailwind CDN(G-2)
- [ ] LineExporter サービス追加(D-2)
- [ ] Sidekiq Web UI mount(E-1)
- [ ] ApplicationJob で Slack エラー通知(E-3)
- [ ] テスト fixture 配置(H-1)
- [ ] Self-hosted runner ラベル(J-1)
- [ ] scripts/transparency_pipeline.py は削除(K-3)
- [ ] **linestamp_generations テーブル / モデルは作らない**
- [ ] **Brand.generation_mode 列は作らない**
- [ ] **StableDiffusionClient / SD 系 Job は作らない**
