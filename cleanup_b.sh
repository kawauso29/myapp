#!/usr/bin/env bash
# =============================================================================
# B案: 透過処理を Rails から撤去 + (A)research.brand_ideas を企画背景としてプロンプトに反映
#       + (C)brand_template の identity_axes 雛形を埋める、ワンショット。
#   - リポジトリのルートで実行する: bash cleanup_b.sh
#
# 方針(確定済み):
#   - ワークフロー = 「完成画像のみ(すっきり)」: 透過済み + LINE規格の PNG を
#     Designer Kit → cowork の line-stamp-packaging スキルで作り、「Upload Processed」だけで受ける。
#     → Upload Raw / Chroma Key ボタン / processing・failed・raw_uploaded 状態を撤去。
#   - パック完成の自動通知(Slack)は廃止。ただしパック完成判定(mark_stamps_complete!)は維持し、
#     通知の代わりに upload_processed コントローラ内で判定する(approve / export_for_line 動線を保つ)。
#   - mini_magick gem は残す(PackRepresentativeImageGenerator が main/tab 画像のリサイズに使用)。
# =============================================================================
set -euo pipefail

if [ ! -f Gemfile ] || [ ! -f config/application.rb ]; then
  echo "ERROR: リポジトリのルートで実行してください (Gemfile が見つかりません)" >&2
  exit 1
fi

echo "==> 1/9 透過処理サービス/ジョブとその spec を削除"
rm -f \
  app/services/linestamp/chroma_key_processor.rb \
  app/jobs/linestamp/process_stamp_image_job.rb \
  spec/services/linestamp/chroma_key_processor_spec.rb \
  spec/jobs/linestamp/process_stamp_image_job_spec.rb

echo "==> 2/9 Stamp モデルを3状態(planned/prompt_ready/processed)に簡素化 + raw_image 撤去"
cat > app/models/linestamp/stamp.rb <<'RUBY'
class Linestamp::Stamp < ApplicationRecord
  include AASM

  # Skip guard for syncer operations where themes are set incrementally
  attr_accessor :skip_primary_theme_guard

  belongs_to :pack, class_name: "Linestamp::Pack"
  belongs_to :primary_communication_theme, class_name: "Linestamp::CommunicationTheme", optional: true
  has_one_attached :processed_image

  has_many :stamp_communication_themes, class_name: "Linestamp::StampCommunicationTheme", dependent: :destroy
  has_many :communication_themes, through: :stamp_communication_themes
  has_many :stamp_attribute_values, class_name: "Linestamp::StampAttributeValue", dependent: :destroy
  has_many :attribute_values, through: :stamp_attribute_values

  validates :position, presence: true, numericality: { greater_than: 0 }
  validates :position, uniqueness: { scope: :pack_id }
  validate :exactly_one_primary_communication_theme,
           if: -> { !skip_primary_theme_guard && stamp_communication_themes.any? }

  scope :with_themes, ->(theme_ids) {
    joins(:stamp_communication_themes)
      .where(linestamp_stamp_communication_themes: { communication_theme_id: theme_ids }).distinct
  }
  scope :with_attributes, ->(value_ids) {
    joins(:stamp_attribute_values)
      .where(linestamp_stamp_attribute_values: { attribute_value_id: value_ids }).distinct
  }

  # Display label for UI (label is the primary text identifier)
  def display_label
    label.presence || "##{position}"
  end

  def sync_primary_communication_theme_id!
    primary_join = stamp_communication_themes.find_by(primary: true)
    new_id = primary_join&.communication_theme_id
    update_column(:primary_communication_theme_id, new_id) if primary_communication_theme_id != new_id
  end

  # 透過 + LINE規格化は cowork の line-stamp-packaging スキル側で行うため、
  # Rails は「完成画像(processed_image)を直接受け取る」だけの3状態に簡素化。
  aasm column: :status do
    state :planned, initial: true
    state :prompt_ready
    state :processed

    event :mark_prompt_ready do
      transitions from: :planned, to: :prompt_ready, guard: :has_prompt?
    end

    event :upload_processed_directly do
      transitions from: %i[planned prompt_ready processed], to: :processed
    end

    event :reset do
      transitions from: :processed, to: :prompt_ready, guard: :has_prompt?
      transitions from: :processed, to: :planned
    end
  end

  # レコード作成時に個別スタンプのプロンプトを自動合成する。
  after_commit on: :create do
    if planned? && prompt.blank?
      Linestamp::ComposeStampPromptsJob.perform_later(id)
    end
  end

  private

  def exactly_one_primary_communication_theme
    primaries = stamp_communication_themes.select(&:primary?).count
    errors.add(:base, "primary な communication_theme は1つだけ必要") if primaries != 1
  end

  def has_prompt?
    prompt.present?
  end
end
RUBY

echo "==> 3/9 Stamps コントローラを書き換え (upload_raw/process_image を撤去、完成判定を upload_processed に移設)"
cat > app/controllers/admin/linestamp/stamps_controller.rb <<'RUBY'
class Admin::Linestamp::StampsController < Admin::BaseController
  before_action :set_stamp, only: %i[show update upload_processed reset designer_kit]

  def show
    @themes = ::Linestamp::CommunicationTheme.active.ordered
    @attribute_values = ::Linestamp::AttributeValue.active.ordered.includes(:axis)
  end

  def update
    update_primary_theme
    sync_secondary_themes
    sync_attribute_values
    redirect_to admin_linestamp_stamp_path(@stamp), notice: "スタンプを更新しました"
  rescue ActiveRecord::RecordInvalid => e
    redirect_to admin_linestamp_stamp_path(@stamp), alert: e.message
  end

  # 透過済み + LINE規格の完成画像を直接受け取る。Raw アップロード / Chroma Key 工程は廃止。
  def upload_processed
    if params[:processed_image].present?
      @stamp.processed_image.attach(params[:processed_image])
      @stamp.upload_processed_directly! if @stamp.may_upload_processed_directly?

      # パック内の全スタンプが揃ったら完成状態へ(自動 Slack 通知は廃止、状態遷移のみ維持)。
      pack = @stamp.pack
      pack.mark_stamps_complete! if pack.all_stamps_processed? && pack.may_mark_stamps_complete?

      redirect_to admin_linestamp_stamp_path(@stamp), notice: "完成画像をアップロードしました。"
    else
      redirect_to admin_linestamp_stamp_path(@stamp), alert: "ファイルが選択されていません。"
    end
  end

  def reset
    if @stamp.may_reset?
      @stamp.processed_image.purge if @stamp.processed_image.attached?
      @stamp.reset!
      redirect_to admin_linestamp_stamp_path(@stamp), notice: "スタンプをリセットしました。"
    else
      redirect_to admin_linestamp_stamp_path(@stamp), alert: "Cannot reset stamp in current state."
    end
  end

  def designer_kit
    kit = ::Linestamp::DesignerKit::Stamp.new(@stamp)
    zip = kit.export
    send_file zip.path, filename: kit.filename, type: "application/zip", disposition: "attachment"
  end

  private

  def set_stamp
    @stamp = ::Linestamp::Stamp.find(params[:id])
  end

  def update_primary_theme
    primary_theme_id = params.dig(:linestamp_stamp, :primary_communication_theme_id).presence&.to_i
    return unless primary_theme_id

    # Set primary on the join record
    @stamp.stamp_communication_themes.update_all(primary: false)
    join = @stamp.stamp_communication_themes.find_or_create_by!(communication_theme_id: primary_theme_id)
    join.update!(primary: true)
  end

  def sync_secondary_themes
    secondary_ids = Array(params.dig(:linestamp_stamp, :communication_theme_ids)).compact_blank.map(&:to_i)
    primary_theme_id = params.dig(:linestamp_stamp, :primary_communication_theme_id).presence&.to_i
    all_theme_ids = (secondary_ids + [primary_theme_id]).compact.uniq

    @stamp.stamp_communication_themes.where.not(communication_theme_id: all_theme_ids).destroy_all
    all_theme_ids.each do |tid|
      @stamp.stamp_communication_themes.find_or_create_by!(communication_theme_id: tid)
    end
  end

  def sync_attribute_values
    value_ids = Array(params.dig(:linestamp_stamp, :attribute_value_ids)).compact_blank.map(&:to_i)
    @stamp.stamp_attribute_values.where.not(attribute_value_id: value_ids).destroy_all
    value_ids.each do |vid|
      @stamp.stamp_attribute_values.find_or_create_by!(attribute_value_id: vid)
    end
  end
end
RUBY

echo "==> 4/9 show.html.erb から Raw 表示 / Upload Raw / Chroma Key ボタンを撤去"
cat > app/views/admin/linestamp/stamps/show.html.erb <<'ERB'
<h1 style="font-size:20px; margin-bottom:20px;">Stamp #<%= @stamp.position %> — <%= @stamp.pack.series_theme %></h1>

<div class="grid-2">
  <div class="card">
    <h2>Stamp Info</h2>
    <dl class="profile-grid">
      <dt>Pack</dt><dd><a href="<%= admin_linestamp_pack_path(@stamp.pack) %>" style="color:#63b3ed;"><%= @stamp.pack.series_theme %></a></dd>
      <dt>Position</dt><dd>#<%= @stamp.position %></dd>
      <dt>Status</dt><dd><span class="badge <%= @stamp.status == 'processed' ? 'active' : 'info' %>"><%= @stamp.status %></span></dd>
      <dt>Label</dt><dd><%= @stamp.label || "—" %></dd>
      <dt>Intent</dt><dd><%= @stamp.intent || "—" %></dd>
      <dt>Situation</dt><dd><%= @stamp.situation || "—" %></dd>
      <dt>Usage Scene</dt><dd><%= @stamp.usage_scene || "—" %></dd>
      <dt>Communication Purpose</dt><dd><%= @stamp.communication_purpose || "—" %></dd>
      <dt>Pose Spec</dt><dd><%= @stamp.pose_spec || "—" %></dd>
      <dt>Props</dt><dd><%= @stamp.props || "—" %></dd>
      <dt>Search Keywords</dt><dd><%= (@stamp.search_keywords || []).join(", ").presence || "—" %></dd>
    </dl>
  </div>

  <div class="card">
    <h2>Images</h2>
    <div style="display:flex; gap:16px; flex-wrap:wrap;">
      <div>
        <p style="font-size:11px; color:#718096;">Processed(完成画像)</p>
        <% if @stamp.processed_image.attached? %>
          <%= image_tag url_for(@stamp.processed_image), style: "max-width:150px; border-radius:4px; background:repeating-conic-gradient(#808080 0% 25%, transparent 0% 50%) 50% / 20px 20px;" %>
        <% else %>
          <div style="width:150px; height:100px; background:#232637; border-radius:4px; display:flex; align-items:center; justify-content:center; color:#4a5568;">No processed</div>
        <% end %>
      </div>
    </div>

    <h3 style="margin-top:16px; font-size:14px;">Reference Images</h3>
    <div style="display:flex; gap:12px; flex-wrap:wrap; margin-top:8px;">
      <div>
        <p style="font-size:10px; color:#718096;">Brand Base</p>
        <% if @stamp.pack.brand.base_image.attached? %>
          <%= image_tag url_for(@stamp.pack.brand.base_image), style: "max-width:120px; border-radius:4px;" %>
        <% else %>
          <p style="font-size:10px; color:#4a5568;">Not uploaded</p>
        <% end %>
      </div>
      <div>
        <p style="font-size:10px; color:#718096;">Pack Sheet</p>
        <% if @stamp.pack.sheet_image.attached? %>
          <%= image_tag url_for(@stamp.pack.sheet_image), style: "max-width:120px; border-radius:4px;" %>
        <% else %>
          <p style="font-size:10px; color:#4a5568;">Not uploaded</p>
        <% end %>
      </div>
    </div>
  </div>
</div>

<div class="card" style="margin-top:16px;">
  <h2>Prompt</h2>
  <% if @stamp.prompt.present? %>
    <pre id="stamp-prompt" style="background:#232637; padding:12px; border-radius:6px; white-space:pre-wrap; font-size:12px; color:#e2e8f0; max-height:300px; overflow-y:auto;"><%= @stamp.prompt %></pre>
    <button onclick="navigator.clipboard.writeText(document.getElementById('stamp-prompt').textContent)" class="btn btn-primary btn-sm" style="margin-top:8px;">📋 Copy Prompt</button>
    <%= link_to "📥 Designer Kit (prompt + 参照画像) をDL",
          designer_kit_admin_linestamp_stamp_path(@stamp),
          class: "btn btn-primary btn-sm",
          style: "margin-top:8px;" %>
  <% else %>
    <p style="color:#718096;">Prompt not yet composed.</p>
  <% end %>
</div>

<div class="card" style="margin-top:16px;">
  <h2>Actions</h2>
  <div style="display:flex; gap:8px; flex-wrap:wrap;">
    <%= form_with url: upload_processed_admin_linestamp_stamp_path(@stamp), method: :post, multipart: true, style: "display:flex; gap:4px; align-items:center;" do |f| %>
      <%= f.file_field :processed_image, accept: "image/png", style: "color:#a0aec0; font-size:12px;" %>
      <%= f.submit "Upload Processed", class: "btn btn-success btn-sm" %>
    <% end %>

    <% if @stamp.may_reset? %>
      <%= button_to "↩️ Reset", reset_admin_linestamp_stamp_path(@stamp), method: :post, class: "btn btn-danger btn-sm" %>
    <% end %>
  </div>
</div>
ERB

echo "==> 5/9 routes.rb から upload_raw / process_image を撤去 (Sidekiq ブロックは触らない)"
perl -ni -e 'print unless /^\s*post :upload_raw\s*$/ || /^\s*post :process_image\s*$/' config/routes.rb

echo "==> 6/9 ProcessStampImageJob の常駐参照を撤去 (initializer + rake)"
perl -ni -e 'print unless /Linestamp::ProcessStampImageJob/' \
  config/initializers/required_job_classes.rb \
  lib/tasks/solid_queue.rake

echo "==> 7/9 (A) PromptComposer に research.brand_ideas を企画背景(参考)として反映"
cat > app/services/linestamp/prompt_composer.rb <<'RUBY'
# frozen_string_literal: true

module Linestamp
  # DB-first のマスタ(CT / 属性軸)を参照して Brand / Pack / Stamp の3階層プロンプトを生成する。
  class PromptComposer
    DEFAULT_COMPOSITIONS = [
      "正面・無表情", "正面・うっすら笑顔", "正面・困り顔", "正面・真顔",
      "横向き立ち", "寝そべり", "座り(マグ抱え)", "椅子に座る",
      "両手合わせ", "サムズアップ", "軽く手を振る", "頬杖"
    ].freeze
    PART_AXES = %w[eyes mouth ears body limbs tail collar].freeze
    IDENTITY_KEYS = {
      "signature" => "シグネチャー(必ず出す識別要素)",
      "voice" => "語り口・トーン",
      "behavior" => "ふるまい・癖"
    }.freeze

    # --- Brand プロンプト (base_image 生成用) ---
    def compose_brand_prompt(brand)
      parts = brand.character_parts || {}
      fonts = brand.font_spec || {}
      demo_names    = brand.attribute_values_by_axis("demographic").pluck(:name).join(", ")
      setting_names = brand.attribute_values_by_axis("setting").pluck(:name).join(", ")
      cts           = brand.communication_themes.pluck(:name).join(" / ")
      identity_block = identity_lines(brand)
      research_block = research_background(brand)

      parts_text = PART_AXES.filter_map { |key|
        val = parts[key] || parts[key.to_sym]
        "- #{parts_label(key)}: #{val}" if val.present?
      }.join("\n        ")

      raw = <<~PROMPT
        あなたは LINE スタンプキャラクター仕様シートのデザイナーです。
        1枚の「キャラ仕様シート画像」を作ってください。これは今後の全パック・全スタンプの参照基準になります。

        【キャラクター定義(必須遵守の核)】
        #{brand.two_part_definition}

        【キャラの優先順位(必須遵守・スコア降順)】
        #{format_tone_axes(brand)}

        【ペルソナとシーン】
        送り手の想定: #{brand.persona_name}
        主な利用シーン: #{setting_names.presence || "汎用"}
        ターゲット世代: #{demo_names.presence || "指定なし"}
        扱うコミュニケーション: #{cts.presence || "未設定"}

        #{research_block.present? ? "#{research_block}\n" : ""}
        #{identity_block.present? ? "【ブランド識別軸(他と間違えられない核)】\n        #{identity_block}\n" : ""}
        【キャラパーツ仕様(全構図で完全統一)】
        #{parts_text}
        - 体色: #{brand.primary_color}

        【フォント仕様(全パックで共通使用)】
        - 書体: #{fonts['primary']}
        - 文字色: #{fonts['color']}
        - フチ: #{fonts['outline']}

        【出力形式】
        1枚の画像内に以下を配置:
        ■ 上段:キャラ構図 12カット(3行 × 4列、すべて同じキャラの統一描写)
        #{format_compositions(brand)}
        ■ 下段:フォント基準 3パターンを横一列
          「おつかれ」「りょうかい」「OK」

        【背景】
        全領域を単色グリーン #{brand.background_color_for_gen}(後工程で透過するため必須)

        【厳守事項】
        - これは個別スタンプ集ではない。シリーズ一覧でもない。1体のキャラを12構図で描く仕様シートである
        - 全12構図で線の太さ・色・塗り・体型を一切変えない#{consistency_clause(brand)}
        - 白背景禁止(白い体が透過処理で消える事故が過去にあり)
        - 文字は丁寧に正しい漢字で。崩れたら再生成
        - キャラの解釈を加えない(髪を描く・服を着せる・装飾を増やす等)
        - スタンプ風のフラットな塗り、影や立体感は最小限
      PROMPT
      tidy(raw)
    end

    # --- Pack プロンプト (sheet_image 生成用) ---
    def compose_pack_prompt(pack)
      brand  = pack.brand
      cts    = pack.communication_themes.pluck(:name).join(", ")
      scenes = (pack.usage_scenes || []).map { |s| setting_label(s) }.join(" / ")
      emos   = (pack.target_emotions || []).join(" / ")
      identity = identity_carry(brand)
      stamps_text = pack.stamps.order(:position).map { |s|
        ct_name = s.primary_communication_theme&.name || "未設定"
        "  ##{s.position} 「#{s.display_label}」 — #{s.situation}(主テーマ: #{ct_name})"
      }.join("\n")

      raw = <<~PROMPT
        あなたは LINE スタンプシリーズ(8枚一覧)のデザイナーです。
        1枚の「シリーズ一覧画像」を作ってください。これがこのパック内のスタンプ品質の参照基準になります。

        【必ず参照する画像】
        Designer に添付する画像:
        - brand.base_image(キャラ仕様シート/12構図+3フォント基準)
        → このパック内のキャラ造形・線・色・塗り・フォントは、すべてこの基準と完全一致させること#{consistency_clause(brand)}

        【シリーズコンセプト】
        シリーズ名: #{pack.series_theme}
        世界観: #{pack.world_view.presence || "未設定"}
        Layer: #{pack.layer}

        【ペルソナと使われ方】
        送り手: #{brand.persona_name}
        送りたい感情: #{emos.presence || "未設定"}
        扱うコミュニケーション: #{cts.presence || "未設定"}
        想定利用シーン: #{scenes.presence || "未設定"}
        #{identity.present? ? identity : ""}

        【採用しない要素(派生パックへの含み)】
        #{pack.excluded_elements.presence || "なし"}

        【8枚のスタンプ(2行 × 4列で1枚画像に配置)】
        #{stamps_text}

        【厳守事項】
        - キャラ仕様は brand.base_image と完全一致（線・色・体型・塗り）#{consistency_clause(brand)}
        - 文字は brand.base_image のフォント基準と完全一致(書体・色・フチ)
        - 各コマは正方形、余白を統一
        - 背景は単色グリーン #{brand.background_color_for_gen}
        - 漢字は丁寧に。崩れたら再生成、ひらがな逃げ禁止
        - 8コマ全てで「キャラの揺れ」を絶対禁止（顔・線・塗りが変わらない）#{consistency_clause(brand)}
        - 1枚画像内で完結させる(個別書き出しは別工程)
      PROMPT
      tidy(raw)
    end

    # 後方互換: 旧名メソッド
    alias_method :compose_pack_sheet_prompt, :compose_pack_prompt

    # --- Stamp プロンプト (個別スタンプ画像 生成用) ---
    def compose_stamp_prompt(stamp)
      pack  = stamp.pack
      brand = pack.brand
      ct    = stamp.primary_communication_theme
      spec  = pack.effective_image_spec
      kw    = stamp.search_keywords || []
      identity = identity_carry(brand)

      raw = <<~PROMPT
        あなたは個別 LINE スタンプのデザイナーです。
        1枚の正方形スタンプを作ってください。

        【必ず参照する画像(両方とも Designer に添付)】
        1. brand.base_image — キャラ仕様シート(揺れ防止)
        2. pack.sheet_image — このシリーズの8枚一覧(パック内一貫性)

        両方の画像に完全一致するキャラ・色・線・フォントで描いてください。

        【スタンプ ##{stamp.position}】
        - 文言: 「#{stamp.display_label}」
        - 主テーマ: #{ct&.name || "未設定"}
        #{ct&.description.present? ? "  (#{ct.description})" : ""}
        - シチュエーション: #{stamp.situation}
        - ポーズ: #{stamp.pose_spec}
        - 小道具: #{stamp.props}
        - 送り手の意図: #{stamp.intent}
        - 利用シーン: #{stamp.usage_scene}
        - コミュニケーション代替価値: #{stamp.communication_purpose}
        #{kw.present? ? "- 検索キーワード: #{kw.join(' / ')}" : ""}

        【キャラ仕様】
        #{identity.present? ? identity : ""}
        brand.base_image と完全一致。線・色・体型・塗りを一切変えない#{consistency_clause(brand)}。
        新しい解釈・装飾・服装を加えない。

        【文字仕様】
        - 文言「#{stamp.display_label}」を中央上部に配置
        - 書体・色・フチは brand.base_image のフォント基準と完全一致
        - 漢字は丁寧に正しく描く。崩れたら再生成、ひらがなに逃げない

        【画像規格】
        - 仕上がりサイズ目安: #{spec&.width || 370}×#{spec&.height || 320}(後工程でトリム)
        - 背景: 単色グリーン #{brand.background_color_for_gen}(全領域)
        - キャラはスタンプ領域の 80% 以上を占める
        - 1画像に1スタンプのみ
      PROMPT
      tidy(raw)
    end

    private

    def tidy(text)
      text.gsub(/[ \t]+\n/, "\n").gsub(/\n{3,}/, "\n\n").strip
    end

    # Research 由来のブランド案メモ(複数候補を含むテキスト)を、企画背景の参考情報として差し込む。
    # research は optional belongs_to なので未紐付け / 空なら何も足さない(従来挙動を完全維持)。
    def research_background(brand)
      ideas = brand.research&.brand_ideas
      return "" if ideas.blank?

      <<~TEXT.strip
        【企画の背景(Research由来・参考情報)】
        このブランドが派生した市場調査のブランド案メモ(複数候補を含む。下記は狙いを理解するための背景であり、画像に文字や複数キャラを描き込む指示ではない):
        #{ideas.to_s.strip}
        ※この調査から1案に絞り込んでこのキャラは設計されている。「ただかわいい動物」の量産にせず、上の狙いと下の識別軸を反映した1体だけを描くこと。
      TEXT
    end

    def format_tone_axes(brand)
      axes = brand.tone_axes
      if axes.present?
        axes.sort_by { |_key, value| -value.to_f }.each_with_index.map { |(key, value), index|
          "#{index + 1}. #{tone_label(key)} #{(value.to_f * 100).round}%"
        }.join("\n        ")
      else
        names = brand.attribute_values_by_axis("tone").pluck(:name)
        names.any? ? names.join(" × ") : "指定なし"
      end
    end

    def format_compositions(brand)
      raw = brand.respond_to?(:base_compositions) ? brand.base_compositions : nil
      list =
        if raw.present?
          raw.map { |composition|
            composition.is_a?(Hash) ? (composition["label"] || composition[:label]) : composition
          }.compact
        else
          DEFAULT_COMPOSITIONS
        end
      list = DEFAULT_COMPOSITIONS if list.empty?
      list.each_slice(4).map { |row| "  #{row.join(' / ')}" }.join("\n")
    end

    def tone_label(slug)
      Linestamp::AttributeValue.for_axis("tone").find_by(slug: slug.to_s)&.name || slug.to_s
    end

    def setting_label(slug)
      Linestamp::AttributeValue.for_axis("setting").find_by(slug: slug.to_s)&.name || slug.to_s
    end

    def identity_lines(brand)
      axes = brand.identity_axes || {}
      lines = IDENTITY_KEYS.filter_map { |key, label|
        val = axes[key] || axes[key.to_sym]
        "- #{label}: #{val}" if val.present?
      }
      lines << "- ブランドカラー(世界観): #{brand.primary_color}" if lines.any? && brand.primary_color.present?
      lines.join("\n        ")
    end

    def identity_carry(brand)
      axes = brand.identity_axes || {}
      pairs = { "signature" => "シグネチャー", "voice" => "語り口" }.filter_map { |key, label|
        val = axes[key] || axes[key.to_sym]
        "#{label}: #{val}" if val.present?
      }
      pairs.empty? ? "" : "識別の継承(brand 由来・厳守): #{pairs.join(' / ')}"
    end

    def consistency_parts(brand)
      parts = brand.character_parts || {}
      PART_AXES.filter_map { |key|
        parts_label(key) if (parts[key] || parts[key.to_sym]).present?
      }.join("・")
    end

    def consistency_clause(brand)
      parts = consistency_parts(brand)
      parts.present? ? "（固定部位: #{parts}）" : ""
    end

    def parts_label(key)
      {
        "eyes" => "目", "mouth" => "口", "ears" => "耳",
        "body" => "体", "limbs" => "手足", "tail" => "しっぽ", "collar" => "首回り"
      }[key.to_s] || key.to_s
    end
  end
end
RUBY

echo "==> 8/9 (C) brand_template の identity_axes 雛形を埋める + 旧 ChromaKeyProcessor 言及を修正"
perl -i -pe 's/^(\s*)signature: "".*$/$1 . q{signature: "首元の小さな丸いタグ(全構図で必ず描く)",}/e' \
  db/seeds/linestamp/imports/_templates/brand_template.rb
perl -i -pe 's/^(\s*)voice: "".*$/$1 . q{voice: "断定しない・語尾がやわらかい",}/e' \
  db/seeds/linestamp/imports/_templates/brand_template.rb
perl -i -pe 's/^(\s*)behavior: "".*$/$1 . q{behavior: "考えるときマグカップを抱える"}/e' \
  db/seeds/linestamp/imports/_templates/brand_template.rb
perl -i -pe 's/ChromaKeyProcessor の緑透過パイプライン保護/cowork の line-stamp-packaging スキルが緑透過するため緑背景固定/' \
  docs/linestamp/08_PLANNING_GUIDE.md

echo "==> 9/9 既存データ(raw_uploaded/processing/failed)を planned/prompt_ready に正規化する migration を生成"
cat > db/migrate/20260601094500_normalize_legacy_stamp_statuses.rb <<'RUBY'
class NormalizeLegacyStampStatuses < ActiveRecord::Migration[8.1]
  # 透過工程の撤去で raw_uploaded / processing / failed 状態が消えたため、
  # 既存レコードを新しい3状態(prompt_ready / planned)に冪等に寄せる。
  def up
    say_with_time "remap legacy stamp statuses → prompt_ready/planned" do
      execute <<~SQL
        UPDATE linestamp_stamps
        SET status = CASE
          WHEN prompt IS NOT NULL AND prompt <> '' THEN 'prompt_ready'
          ELSE 'planned'
        END
        WHERE status IN ('raw_uploaded', 'processing', 'failed')
      SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
RUBY

# CLAUDE.md に変更記録を追記(非破壊)
cat >> CLAUDE.md <<'MD'

## 変更記録: B案 — 透過処理を Rails から撤去 + 企画背景(Research)反映 + 雛形整備

- **透過処理の撤去**: 透過 + LINE規格化は cowork の `line-stamp-packaging` スキルで行うため、Rails 側の `ChromaKeyProcessor` / `ProcessStampImageJob`(+ 各 spec)を削除。
- **Stamp 状態を3つに簡素化**: `planned → prompt_ready → processed`。`raw_uploaded / processing / failed` と `raw_image` 添付を撤去。管理画面は「Upload Processed(完成画像)」のみ受け付ける(Upload Raw / Chroma Key ボタンを撤去)。
- **パック完成の自動 Slack 通知は廃止**。ただしパック完成判定(`pack.mark_stamps_complete!`)は維持し、`stamps_controller#upload_processed` 内で判定する(approve / export_for_line 動線を保持)。
- **mini_magick gem は残す**: `PackRepresentativeImageGenerator` が main(240×240)/tab(96×74) 画像のリサイズに使用しているため。
- **(A)** `PromptComposer#compose_brand_prompt` に `brand.research&.brand_ideas` を「企画の背景(参考)」として差し込み(nil ガードあり、research 未紐付けなら従来どおり無出力)。差別化は引き続き Research の brand_idea 起点 + identity_axes の2段。
- **(C)** `brand_template.rb` の `identity_axes` 雛形に具体値(signature/voice/behavior)を充填。`08_PLANNING_GUIDE.md` の旧 ChromaKeyProcessor 言及を修正。
- routes.rb / required_job_classes.rb / lib/tasks/solid_queue.rake から撤去シンボルへの参照を除去。既存データ正規化 migration `NormalizeLegacyStampStatuses` を追加(デプロイの db:migrate で適用)。
- 注: `docs/linestamp/` 配下の旧仕様(ChromaKeyProcessor / raw_image)記述は履歴として残置。
MD

echo
echo "============================================================"
echo " 残存参照チェック(コードは0件であるべき / docs は履歴として残置):"
grep -rn --include='*.rb' --include='*.erb' \
  -E 'ChromaKeyProcessor|ProcessStampImageJob|upload_raw|process_image|raw_uploaded|raw_image' \
  app config lib spec 2>/dev/null || echo "  (なし)"
echo "------------------------------------------------------------"
echo " B案クリーンアップ完了。次の確認を推奨:"
echo "    bin/rubocop"
echo "    bundle exec rspec"
echo "    RAILS_ENV=production bin/rails db:migrate   # デプロイ時に自動実行される"
echo "    git diff --stat"
echo "============================================================"
