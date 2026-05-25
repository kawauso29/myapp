# 06. 管理画面仕様 (Pack 承認チェックボックス)

## 方針

**API mode な myapp に Rails ERB 管理画面を追加** する。React Native フロントとは別ルートで提供:
- パス: `/admin/linestamp/...`
- 認証: Devise + admin ロール(既存仕組み流用)
- 見た目: 軽量 ERB + Tailwind CDN またはシンプルな素CSS

採用しない選択肢:
- Administrate gem(オーバーキル)
- React Native 統合(本筋のSNSアプリと混ざる)

---

## ルーティング

```ruby
# config/routes.rb (追加分)
Rails.application.routes.draw do
  # 既存のroutes...

  authenticate :user, ->(user) { user.admin? } do
    namespace :admin do
      namespace :linestamp do
        root to: "dashboard#index"
        resources :brands, only: [:index, :show]
        resources :packs do
          member do
            patch :approve
            patch :unapprove
          end
          resources :stamps, only: [:index, :show] do
            member do
              patch :retry  # 再生成
            end
          end
        end
        resources :researches, only: [:index, :show]
        resources :submissions, only: [:index, :show, :update]
      end
    end
  end

  # GitHub Actions からの sync 受け口(認証は別)
  post "/webhooks/linestamp/sync", to: "linestamp/webhooks#sync"
end
```

---

## コントローラ

### 1. Admin::Linestamp::DashboardController

```ruby
# app/controllers/admin/linestamp/dashboard_controller.rb
module Admin
  module Linestamp
    class DashboardController < AdminController  # 既存のAdminController を継承
      def index
        @stats = {
          brands: {
            planned:      ::Linestamp::Brand.where(state: "planned").count,
            ready:        ::Linestamp::Brand.where(state: "base_ready").count,
          },
          packs: {
            pending:      ::Linestamp::Pack.pending_approval.count,
            approved:     ::Linestamp::Pack.approved.where.not(state: "complete").count,
            complete:     ::Linestamp::Pack.where(state: "complete").count,
          },
          stamps: {
            in_progress:  ::Linestamp::Stamp.where.not(state: %w[planned processed]).count,
            processed:    ::Linestamp::Stamp.where(state: "processed").count,
          },
          submissions: {
            submitted:    ::Linestamp::Submission.where(state: "submitted").count,
            selling:      ::Linestamp::Submission.where(state: "selling").count,
          }
        }

        @pending_packs = ::Linestamp::Pack.pending_approval
                                          .includes(:brand)
                                          .order(created_at: :desc)
                                          .limit(20)
        @recent_completed = ::Linestamp::Stamp.where(state: "processed")
                                              .includes(:pack)
                                              .order(updated_at: :desc)
                                              .limit(8)
      end
    end
  end
end
```

### 2. Admin::Linestamp::PacksController

```ruby
# app/controllers/admin/linestamp/packs_controller.rb
module Admin
  module Linestamp
    class PacksController < AdminController
      def index
        @packs = ::Linestamp::Pack.includes(:brand)
                                   .order(approved: :asc, created_at: :desc)
                                   .page(params[:page])
      end

      def show
        @pack = ::Linestamp::Pack.includes(:brand, stamps: :generations).find(params[:id])
      end

      def approve
        @pack = ::Linestamp::Pack.find(params[:id])
        @pack.approve!
        redirect_to admin_linestamp_packs_path, notice: "Pack \"#{@pack.slug}\" を承認しました"
      end

      def unapprove
        @pack = ::Linestamp::Pack.find(params[:id])
        @pack.unapprove!
        redirect_to admin_linestamp_packs_path, notice: "Pack \"#{@pack.slug}\" の承認を取り消しました"
      end
    end
  end
end
```

### 3. Admin::Linestamp::StampsController

```ruby
module Admin
  module Linestamp
    class StampsController < AdminController
      def show
        @stamp = ::Linestamp::Stamp.includes(:generations, pack: :brand).find(params[:id])
      end

      # 再生成: 状態を image_generating に戻して GenerateStampImageJob を起動
      def retry
        @stamp = ::Linestamp::Stamp.find(params[:id])

        # 既存 raw_image を purge
        @stamp.raw_image.purge if @stamp.raw_image.attached?
        @stamp.processed_image.purge if @stamp.processed_image.attached?
        @stamp.update!(state: "prompt_ready", rejection_reason: nil, error_message: nil)

        ::Linestamp::GenerateStampImageJob.perform_later(@stamp.id)

        redirect_to admin_linestamp_pack_stamp_path(@stamp.pack_id, @stamp),
                    notice: "再生成キューに投入しました"
      end
    end
  end
end
```

### 4. Webhook Controller

```ruby
# app/controllers/linestamp/webhooks_controller.rb
module Linestamp
  class WebhooksController < ApplicationController
    skip_before_action :verify_authenticity_token

    before_action :verify_sync_token, only: [:sync]

    def sync
      Linestamp::SyncBrandSourcesJob.perform_later
      render json: { status: "accepted" }, status: :accepted
    end

    private

    def verify_sync_token
      token = request.headers["Authorization"]&.split(" ")&.last
      head :unauthorized unless ActiveSupport::SecurityUtils.secure_compare(
        token.to_s, ENV.fetch("LINESTAMP_SYNC_TOKEN", "")
      )
    end
  end
end
```

(self-hosted runner からは `curl http://localhost:3000/webhooks/linestamp/sync` で叩ける。token は環境変数経由)

---

## ビュー(主要ページ)

### Dashboard (`app/views/admin/linestamp/dashboard/index.html.erb`)

```erb
<% content_for :title, "LINEスタンプ工房" %>

<div class="p-6 space-y-6">
  <h1 class="text-2xl font-bold">LINEスタンプ工房 ダッシュボード</h1>

  <!-- KPI カード -->
  <div class="grid grid-cols-4 gap-4">
    <div class="card">
      <div class="text-sm text-gray-500">Brand</div>
      <div class="text-3xl"><%= @stats[:brands][:ready] %></div>
      <div class="text-xs">planned: <%= @stats[:brands][:planned] %></div>
    </div>
    <div class="card">
      <div class="text-sm text-gray-500">Pack 承認待ち</div>
      <div class="text-3xl"><%= @stats[:packs][:pending] %></div>
      <div class="text-xs">approved: <%= @stats[:packs][:approved] %></div>
    </div>
    <div class="card">
      <div class="text-sm text-gray-500">Stamps processed</div>
      <div class="text-3xl"><%= @stats[:stamps][:processed] %></div>
      <div class="text-xs">in-progress: <%= @stats[:stamps][:in_progress] %></div>
    </div>
    <div class="card">
      <div class="text-sm text-gray-500">Submissions</div>
      <div class="text-3xl"><%= @stats[:submissions][:selling] %></div>
      <div class="text-xs">submitted: <%= @stats[:submissions][:submitted] %></div>
    </div>
  </div>

  <!-- 承認待ち Pack 一覧 -->
  <div>
    <h2 class="text-xl font-semibold mb-2">承認待ち Pack</h2>
    <table class="w-full">
      <thead>
        <tr><th>Brand</th><th>Series</th><th>Layer</th><th>作成日</th><th>操作</th></tr>
      </thead>
      <tbody>
        <% @pending_packs.each do |pack| %>
          <tr>
            <td><%= pack.brand.character_name %></td>
            <td><%= link_to pack.series_theme, admin_linestamp_pack_path(pack) %></td>
            <td><%= pack.layer %></td>
            <td><%= pack.created_at.strftime("%m/%d") %></td>
            <td>
              <%= button_to "承認", approve_admin_linestamp_pack_path(pack),
                            method: :patch, class: "btn btn-primary" %>
            </td>
          </tr>
        <% end %>
      </tbody>
    </table>
  </div>

  <!-- 最近完成した stamps -->
  <div>
    <h2 class="text-xl font-semibold mb-2">最近完成した Stamp</h2>
    <div class="grid grid-cols-4 gap-3">
      <% @recent_completed.each do |stamp| %>
        <div class="border rounded p-2">
          <%= image_tag rails_blob_path(stamp.processed_image), class: "w-full" if stamp.processed_image.attached? %>
          <div class="text-xs mt-1"><%= stamp.label %></div>
          <div class="text-xs text-gray-500"><%= stamp.pack.brand.character_name %> / #<%= stamp.number %></div>
        </div>
      <% end %>
    </div>
  </div>
</div>
```

### Pack 一覧 (`app/views/admin/linestamp/packs/index.html.erb`)

```erb
<div class="p-6">
  <h1 class="text-2xl font-bold mb-4">Pack 一覧</h1>

  <table class="w-full">
    <thead>
      <tr>
        <th>✓</th><th>Brand</th><th>Pack</th><th>Series Theme</th>
        <th>Layer</th><th>State</th><th>Approved</th><th>作成日</th>
      </tr>
    </thead>
    <tbody>
      <% @packs.each do |pack| %>
        <tr class="<%= 'bg-green-50' if pack.approved? %>">
          <td>
            <% if pack.approved? %>
              <%= button_to "✓", unapprove_admin_linestamp_pack_path(pack), method: :patch,
                            class: "text-green-600 font-bold", form: { class: "inline" } %>
            <% else %>
              <%= button_to "□", approve_admin_linestamp_pack_path(pack), method: :patch,
                            class: "text-gray-400", form: { class: "inline" } %>
            <% end %>
          </td>
          <td><%= pack.brand.character_name %></td>
          <td><%= link_to pack.slug, admin_linestamp_pack_path(pack) %></td>
          <td><%= pack.series_theme %></td>
          <td><%= pack.layer %></td>
          <td>
            <span class="badge state-<%= pack.state %>"><%= pack.state %></span>
          </td>
          <td><%= pack.approved_at&.strftime("%m/%d %H:%M") %></td>
          <td><%= pack.created_at.strftime("%m/%d") %></td>
        </tr>
      <% end %>
    </tbody>
  </table>

  <%= paginate @packs if defined?(Kaminari) %>
</div>
```

### Pack 詳細 (`app/views/admin/linestamp/packs/show.html.erb`)

```erb
<div class="p-6 space-y-4">
  <h1 class="text-2xl font-bold">
    <%= @pack.brand.character_name %> / <%= @pack.slug %>
    <span class="badge state-<%= @pack.state %>"><%= @pack.state %></span>
  </h1>

  <p><%= @pack.series_theme %> (Layer: <%= @pack.layer %>)</p>

  <% if @pack.approved? %>
    <%= button_to "承認を取り消す", unapprove_admin_linestamp_pack_path(@pack), method: :patch,
                  class: "btn btn-warning" %>
  <% else %>
    <%= button_to "✅ このPackを承認する", approve_admin_linestamp_pack_path(@pack), method: :patch,
                  class: "btn btn-primary text-lg" %>
  <% end %>

  <!-- パックシート画像 -->
  <% if @pack.sheet_image.attached? %>
    <div>
      <h3>シリーズベース画像</h3>
      <%= image_tag rails_blob_path(@pack.sheet_image), class: "max-w-md" %>
    </div>
  <% end %>

  <!-- 8枚のstamp -->
  <div>
    <h3>個別 Stamp (<%= @pack.stamps.count %>枚)</h3>
    <div class="grid grid-cols-4 gap-3">
      <% @pack.stamps.order(:number).each do |stamp| %>
        <div class="border rounded p-2">
          <% if stamp.processed_image.attached? %>
            <%= image_tag rails_blob_path(stamp.processed_image), class: "w-full" %>
          <% elsif stamp.raw_image.attached? %>
            <%= image_tag rails_blob_path(stamp.raw_image), class: "w-full opacity-70" %>
            <div class="text-xs">(raw)</div>
          <% else %>
            <div class="bg-gray-100 h-32 flex items-center justify-center">
              <span class="text-gray-400 text-xs"><%= stamp.state %></span>
            </div>
          <% end %>
          <div class="text-xs mt-1"><%= stamp.label %></div>
          <div class="text-xs text-gray-500">#<%= stamp.number %></div>
          <% if stamp.state == "error" || stamp.state == "processed" %>
            <%= button_to "再生成", retry_admin_linestamp_pack_stamp_path(@pack, stamp), method: :patch,
                          class: "btn btn-xs mt-1" %>
          <% end %>
        </div>
      <% end %>
    </div>
  </div>

  <!-- メタ情報 -->
  <details>
    <summary>pack_md 原本</summary>
    <pre class="bg-gray-50 p-3 text-xs"><%= @pack.pack_md %></pre>
  </details>
</div>
```

---

## CSS

最初は素CSSで OK。あとで Tailwind CDN を `<head>` に追加すれば全部きれいになる:

```erb
<!-- app/views/layouts/admin.html.erb -->
<head>
  ...
  <script src="https://cdn.tailwindcss.com"></script>
</head>
```

---

## 認証

既存の `AdminController` (admin ロール) を継承する想定。なければ:

```ruby
# app/controllers/admin_controller.rb
class AdminController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin

  layout "admin"

  private

  def require_admin
    redirect_to root_path, alert: "管理者権限が必要です" unless current_user&.admin?
  end
end
```

`User#admin?` がない場合は `boolean :admin` カラムを users に追加 or 既存ロール機構に乗せる。

---

## 機能の優先度

| 機能 | 優先度 | Issue |
|---|---|---|
| Dashboard 表示 | 高 | #16 |
| Pack 承認/解除 | 高 | #17 |
| Pack 詳細(stamp 一覧 + 再生成) | 高 | #18 |
| Brand 一覧/詳細 | 中 | #19 |
| Research 一覧 | 低 | #19 |
| Submission 管理 | 低 | #19 |
