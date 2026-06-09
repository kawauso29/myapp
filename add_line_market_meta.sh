#!/usr/bin/env bash
# =============================================================================
# add_line_market_meta.sh
#
# LINE Creators Market 申請用の管理画面設定を3点追加する(冪等・再実行安全)。
#
#   (1) 固定値カード        … LINECreator側の全スタンプ共通設定を「静的表示」
#                              (スタンプ/日本語/AI使用あり/全エリア/写真なし/
#                               アレンジ不参加/Collaboration不参加/手動販売開始)
#   (2) タイトル+説明文      … Pack(=LINE申請単位)に日本語と英語の両方を保持。
#                              文字数制限: タイトル 40 / 説明文 160(LINE仕様)。
#                              日本語は作成時に決定論で自動生成。英語は Rails に
#                              翻訳エンジンが無いため Cowork 貼り付け用プロンプトを
#                              自動生成して管理画面にコピーボタンで提示する。
#   (3) 検索タグ            … Stamp の既存 search_keywords を管理画面で編集。
#                              1スタンプ最大9個(LINE仕様)。作成時に候補を自動投入。
#
# 制約(社内メモ準拠):
#   - ARTS213 dev box には Ruby が無い → 本スクリプトは ruby/rails/rspec を一切呼ばない。
#   - CI は db:schema:load を使うため db/schema.rb を手編集し version を更新する。
#     併せて本番 db:migrate 用に冪等 migration も同梱する。
#   - 既存 update アクション(sync_themes/sync_attribute_values の destroy_all)は
#     一切再利用しない。専用アクションを新設する。
#   - 既存 ComposePackSheetPromptJob / ComposeStampPromptsJob に追記する形で
#     自動生成を行い、新規 Job 登録(required_job_classes)を増やさない。
#
# 使い方:  bash add_line_market_meta.sh
# =============================================================================
set -euo pipefail

REPO="${REPO:-$HOME/source/myapp}"
BRANCH="main"
OLD_SCHEMA_VERSION="2026_06_01_094500"
NEW_SCHEMA_VERSION="2026_06_02_120000"
MIGRATION_TS="20260602120000"

cd "$REPO"

echo "==> origin/main に同期"
git fetch origin "$BRANCH"
git checkout "$BRANCH"
git reset --hard "origin/$BRANCH"

# ---------------------------------------------------------------------------
# 全ファイル編集を Python で冪等に実施(各編集はセンチネルで二重適用を防ぐ)
# ---------------------------------------------------------------------------
python3 - "$OLD_SCHEMA_VERSION" "$NEW_SCHEMA_VERSION" "$MIGRATION_TS" <<'PYEOF'
import sys, os, io

OLD_VER, NEW_VER, MIG_TS = sys.argv[1], sys.argv[2], sys.argv[3]

def read(p):
    with io.open(p, encoding="utf-8") as f:
        return f.read()

def write(p, s):
    with io.open(p, "w", encoding="utf-8") as f:
        f.write(s)
    print("  edited:", p)

def insert_before(text, anchor, block, sentinel):
    if sentinel in text:
        print("  skip (already applied):", sentinel)
        return text, False
    idx = text.find(anchor)
    if idx == -1:
        raise SystemExit("ANCHOR NOT FOUND: %r" % anchor)
    return text[:idx] + block + text[idx:], True

def insert_after_line(text, anchor_line, block, sentinel):
    if sentinel in text:
        print("  skip (already applied):", sentinel)
        return text, False
    idx = text.find(anchor_line)
    if idx == -1:
        raise SystemExit("ANCHOR NOT FOUND: %r" % anchor_line)
    end = idx + len(anchor_line)
    # 行末まで進める
    nl = text.find("\n", end)
    if nl == -1:
        nl = len(text)
    return text[:nl+1] + block + text[nl+1:], True

# ===========================================================================
# 1) db/schema.rb — カラム追加 + version 更新
# ===========================================================================
p = "db/schema.rb"
s = read(p)

# 1a. version 更新
if OLD_VER in s:
    s = s.replace("version: %s" % OLD_VER, "version: %s" % NEW_VER, 1)
    print("  schema version ->", NEW_VER)
else:
    print("  schema version: already bumped or not found (continuing)")

# 1b. brands カラム
brand_cols = (
    '    t.string "line_creator_name", comment: "LINE クリエイター名(全パック共通・ブランド固定)"\n'
    '    t.string "line_copyright", comment: "LINE コピーライト表記(50文字以内)"\n'
)
s, _ = insert_after_line(
    s,
    'create_table "linestamp_brands", force: :cascade do |t|',
    brand_cols,
    'line_creator_name',
)

# 1c. packs カラム(タイトル/説明文 JA+EN + Cowork用プロンプト)
pack_cols = (
    '    t.string "line_title_ja", comment: "LINE掲載タイトル 日本語(40文字以内)"\n'
    '    t.string "line_title_en", comment: "LINE掲載タイトル 英語(40文字以内)"\n'
    '    t.text "line_desc_ja", comment: "LINE掲載説明文 日本語(160文字以内)"\n'
    '    t.text "line_desc_en", comment: "LINE掲載説明文 英語(160文字以内)"\n'
    '    t.text "line_meta_prompt", comment: "英語版タイトル/説明文/タグ生成用 Cowork プロンプト"\n'
)
s, _ = insert_after_line(
    s,
    'create_table "linestamp_packs", force: :cascade do |t|',
    pack_cols,
    'line_title_ja',
)
write(p, s)

# ===========================================================================
# 2) db/migrate — 本番 db:migrate 用の冪等 migration(if_not_exists)
# ===========================================================================
mig_path = "db/migrate/%s_add_line_market_meta.rb" % MIG_TS
if not os.path.exists(mig_path):
    mig = '''class AddLineMarketMeta < ActiveRecord::Migration[8.1]
  def up
    unless column_exists?(:linestamp_brands, :line_creator_name)
      add_column :linestamp_brands, :line_creator_name, :string,
                 comment: "LINE クリエイター名(全パック共通・ブランド固定)"
    end
    unless column_exists?(:linestamp_brands, :line_copyright)
      add_column :linestamp_brands, :line_copyright, :string,
                 comment: "LINE コピーライト表記(50文字以内)"
    end

    unless column_exists?(:linestamp_packs, :line_title_ja)
      add_column :linestamp_packs, :line_title_ja, :string,
                 comment: "LINE掲載タイトル 日本語(40文字以内)"
    end
    unless column_exists?(:linestamp_packs, :line_title_en)
      add_column :linestamp_packs, :line_title_en, :string,
                 comment: "LINE掲載タイトル 英語(40文字以内)"
    end
    unless column_exists?(:linestamp_packs, :line_desc_ja)
      add_column :linestamp_packs, :line_desc_ja, :text,
                 comment: "LINE掲載説明文 日本語(160文字以内)"
    end
    unless column_exists?(:linestamp_packs, :line_desc_en)
      add_column :linestamp_packs, :line_desc_en, :text,
                 comment: "LINE掲載説明文 英語(160文字以内)"
    end
    unless column_exists?(:linestamp_packs, :line_meta_prompt)
      add_column :linestamp_packs, :line_meta_prompt, :text,
                 comment: "英語版タイトル/説明文/タグ生成用 Cowork プロンプト"
    end
  end

  def down
    remove_column :linestamp_brands, :line_creator_name, if_exists: true
    remove_column :linestamp_brands, :line_copyright, if_exists: true
    remove_column :linestamp_packs, :line_title_ja, if_exists: true
    remove_column :linestamp_packs, :line_title_en, if_exists: true
    remove_column :linestamp_packs, :line_desc_ja, if_exists: true
    remove_column :linestamp_packs, :line_desc_en, if_exists: true
    remove_column :linestamp_packs, :line_meta_prompt, if_exists: true
  end
end
'''
    write(mig_path, mig)
else:
    print("  skip (migration exists):", mig_path)

# ===========================================================================
# 3) モデル: バリデーション
# ===========================================================================
# 3a. Pack — タイトル40 / 説明文160
p = "app/models/linestamp/pack.rb"
s = read(p)
pack_val = (
    "\n  # LINE_META_VALIDATIONS — LINE Creators Market 文字数制限\n"
    '  validates :line_title_ja, length: { maximum: 40 }, allow_blank: true\n'
    '  validates :line_title_en, length: { maximum: 40 }, allow_blank: true\n'
    '  validates :line_desc_ja, length: { maximum: 160 }, allow_blank: true\n'
    '  validates :line_desc_en, length: { maximum: 160 }, allow_blank: true\n'
)
s, _ = insert_after_line(
    s,
    'validates :sales_count, numericality: { greater_than_or_equal_to: 0, only_integer: true }',
    pack_val,
    "LINE_META_VALIDATIONS",
)
write(p, s)

# 3b. Brand — コピーライト50
p = "app/models/linestamp/brand.rb"
s = read(p)
brand_val = (
    "\n  # LINE_META_VALIDATIONS — コピーライト表記上限\n"
    '  validates :line_copyright, length: { maximum: 50 }, allow_blank: true\n'
)
s, _ = insert_after_line(
    s,
    'validates :series_name, presence: true',
    brand_val,
    "LINE_META_VALIDATIONS",
)
write(p, s)

# 3c. Stamp — タグ最大9
p = "app/models/linestamp/stamp.rb"
s = read(p)
stamp_val = (
    "\n  # LINE_TAGS_VALIDATION — LINE 検索タグは最大9個\n"
    "  validate :search_keywords_within_limit\n"
)
s, _ = insert_after_line(
    s,
    'validates :position, uniqueness: { scope: :pack_id }',
    stamp_val,
    "LINE_TAGS_VALIDATION",
)
# private メソッド本体(has_prompt? の前に挿入)
if "def search_keywords_within_limit" not in s:
    anchor = "  def has_prompt?"
    body = (
        "  def search_keywords_within_limit\n"
        "    return if search_keywords.blank?\n"
        '    errors.add(:search_keywords, "は最大9個までです") if Array(search_keywords).size > 9\n'
        "  end\n\n"
    )
    idx = s.find(anchor)
    if idx == -1:
        raise SystemExit("ANCHOR NOT FOUND: has_prompt?")
    s = s[:idx] + body + s[idx:]
write(p, s)

# ===========================================================================
# 4) PromptComposer — 日本語メタ自動生成 + Cowork プロンプト生成
# ===========================================================================
p = "app/services/linestamp/prompt_composer.rb"
s = read(p)
if "def compose_pack_line_meta" not in s:
    methods = '''
    # --- LINE掲載メタ: 日本語タイトル/説明文を決定論で自動生成 ---
    # 翻訳エンジンは Rails に無いため英語はここでは作らない(Cowork プロンプト側で生成)。
    def compose_pack_line_meta(pack)
      brand = pack.brand
      title = pack.series_theme.to_s.strip
      title = "#{brand.character_name}#{title}" if title.length < 6 && brand.character_name.present?

      emos   = (pack.target_emotions || []).reject(&:blank?).join("・")
      scenes = (pack.usage_scenes || []).map { |sc| setting_label(sc) }.reject(&:blank?).join("・")

      parts = []
      parts << "#{brand.character_name}の#{pack.series_theme}スタンプ。" if brand.character_name.present?
      parts << "#{scenes}で使える。" if scenes.present?
      parts << "#{emos}を伝える全8種。" if emos.present?
      parts << pack.world_view.to_s.strip if pack.world_view.present?
      desc = parts.join("")

      { title_ja: truncate_line(title, 40), desc_ja: truncate_line(desc, 160) }
    end

    # --- 英語版タイトル/説明文 + 各スタンプ検索タグ(最大9)を作る Cowork プロンプト ---
    def compose_pack_line_meta_prompt(pack)
      brand = pack.brand
      meta  = compose_pack_line_meta(pack)
      stamps_text = pack.stamps.order(:position).map { |st|
        "  ##{st.position} 「#{st.display_label}」 #{st.situation}"
      }.join("\\n")

      raw = <<~PROMPT
        あなたは LINE Creators Market のストア掲載文ライター兼ローカライザーです。
        以下の日本語メタ情報をもとに、英語版のタイトル・説明文と、各スタンプの検索タグを作ってください。

        【キャラクター】#{brand.character_name}(#{brand.series_name})
        【シリーズ】#{pack.series_theme}
        【日本語タイトル(確定・40文字以内)】#{meta[:title_ja]}
        【日本語説明文(確定・160文字以内)】#{meta[:desc_ja]}

        【8スタンプ】
        #{stamps_text}

        【出力(厳守)】
        1. 英語タイトル: 40文字以内。日本語タイトルの意味を保つ自然な英語。
        2. 英語説明文: 160文字以内。海外ユーザーが検索・購入したくなる自然な英語。日本語説明文の意味を保つ。
        3. 各スタンプの検索タグ: 1スタンプにつき最大9個。送る場面・感情・あいさつ語など短い日本語。
           「#1: タグ, タグ, ...」のように position ごとに列挙する。
        ※ タイトル40 / 説明文160 / タグ9個 の上限を必ず守る。超えたら短くやり直す。
      PROMPT
      tidy(raw)
    end

'''
    s, _ = insert_before(s, "    private\n", methods, "def compose_pack_line_meta")

# private ヘルパ truncate_line
if "def truncate_line" not in s:
    helper = (
        "\n    def truncate_line(str, max)\n"
        "      str = str.to_s.strip\n"
        "      str.length > max ? str[0, max] : str\n"
        "    end\n"
    )
    # 既存 private ブロックの tidy 直後に追加
    anchor = "    def tidy(text)\n      text.gsub"
    idx = s.find(anchor)
    if idx == -1:
        # フォールバック: private 直後
        anchor2 = "    private\n"
        idx2 = s.find(anchor2)
        if idx2 == -1:
            raise SystemExit("ANCHOR NOT FOUND: private (composer)")
        s = s[:idx2+len(anchor2)] + helper + s[idx2+len(anchor2):]
    else:
        nl = s.find("\n    end\n", idx)
        nl_end = nl + len("\n    end\n")
        s = s[:nl_end] + helper + s[nl_end:]
write(p, s)

# ===========================================================================
# 5) Job 追記: 既存 Compose Job に自動生成を相乗りさせる(新規Job登録を増やさない)
# ===========================================================================
# 5a. ComposePackSheetPromptJob — sheet_prompt 後に日本語メタ + Cowork プロンプトを充填
p = "app/jobs/linestamp/compose_pack_sheet_prompt_job.rb"
s = read(p)
if "compose_pack_line_meta" not in s:
    anchor = "      pack.update!(sheet_prompt: prompt)\n"
    block = (
        "\n      # LINE掲載メタ(日本語)と Cowork 用英語プロンプトを未設定時のみ自動生成\n"
        "      meta = composer.compose_pack_line_meta(pack)\n"
        "      pack.update_columns(\n"
        "        line_title_ja: pack.line_title_ja.presence || meta[:title_ja],\n"
        "        line_desc_ja:  pack.line_desc_ja.presence  || meta[:desc_ja],\n"
        "        line_meta_prompt: pack.line_meta_prompt.presence || composer.compose_pack_line_meta_prompt(pack)\n"
        "      )\n"
    )
    idx = s.find(anchor)
    if idx == -1:
        raise SystemExit("ANCHOR NOT FOUND: pack.update!(sheet_prompt")
    end = idx + len(anchor)
    s = s[:end] + block + s[end:]
    write(p, s)
else:
    print("  skip (already applied): pack job")

# 5b. ComposeStampPromptsJob — 検索タグ候補を作成時に自動投入(最大9)
p = "app/jobs/linestamp/compose_stamp_prompts_job.rb"
s = read(p)
if "search_keywords" not in s:
    anchor = "      stamp.update!(prompt: prompt)\n"
    block = (
        "\n      # 検索タグ未設定なら候補を自動投入(ラベル/主テーマ/属性から最大9個)\n"
        "      if stamp.search_keywords.blank?\n"
        "        seeds = []\n"
        "        seeds << stamp.display_label if stamp.label.present?\n"
        "        seeds << stamp.primary_communication_theme&.name\n"
        "        seeds.concat(stamp.communication_themes.pluck(:name))\n"
        "        seeds.concat(stamp.attribute_values.pluck(:name))\n"
        "        seeds = seeds.compact.map { |x| x.to_s.strip }.reject(&:blank?).uniq.first(9)\n"
        "        stamp.update_column(:search_keywords, seeds) if seeds.any?\n"
        "      end\n"
    )
    idx = s.find(anchor)
    if idx == -1:
        raise SystemExit("ANCHOR NOT FOUND: stamp.update!(prompt")
    end = idx + len(anchor)
    s = s[:end] + block + s[end:]
    write(p, s)
else:
    print("  skip (already applied): stamp job")
PYEOF

echo "==> ルーティング: 専用更新アクションを冪等に追加"
python3 - <<'PYEOF2'
import io
p = "config/routes.rb"
with io.open(p, encoding="utf-8") as f:
    s = f.read()

def ensure_member_route(s, head, line):
    if line.strip() in s and s.count(line.strip()) >= 1:
        # 既に当該 patch 行があるブロックか判定: 単純に全文に1つでもあればOK化のため
        pass
    # ブロック単位で挿入(既に同ブロックにあれば skip)
    import re
    idx = s.find(head)
    if idx == -1:
        raise SystemExit("ANCHOR NOT FOUND: %r" % head)
    # ブロックの end までの範囲
    m = s.find("member do", idx)
    blk_end = s.find("end", m)
    segment = s[m:blk_end]
    if line.strip() in segment:
        return s, False
    nl = s.find("\n", m)
    return s[:nl+1] + line + s[nl+1:], True

changed = False
s, c1 = ensure_member_route(
    s,
    'resources :brands, only: [ :index, :show, :update ] do',
    "          patch :update_line_meta\n",
)
changed = changed or c1
s, c2 = ensure_member_route(
    s,
    'resources :packs, only: [ :index, :show, :update ] do',
    "          patch :update_line_meta\n",
)
changed = changed or c2
s, c3 = ensure_member_route(
    s,
    'resources :stamps, only: [ :show, :update ] do',
    "          patch :update_tags\n",
)
changed = changed or c3

with io.open(p, "w", encoding="utf-8") as f:
    f.write(s)
print("  routes updated:", changed)
PYEOF2

echo "==> コントローラ / ビュー編集"
python3 - <<'PYEOF3'
import io

def read(p):
    with io.open(p, encoding="utf-8") as f:
        return f.read()
def write(p, s):
    with io.open(p, "w", encoding="utf-8") as f:
        f.write(s)
    print("  edited:", p)

# --- PacksController: update_line_meta + line_meta_params ---
p = "app/controllers/admin/linestamp/packs_controller.rb"
s = read(p)
if "def update_line_meta" not in s:
    s = s.replace(
        "before_action :set_pack, only: %i[show update upload_sheet approve export_for_line upload_main_image generate_main_image upload_tab_image generate_tab_image]",
        "before_action :set_pack, only: %i[show update update_line_meta upload_sheet approve export_for_line upload_main_image generate_main_image upload_tab_image generate_tab_image]",
        1,
    )
    action = (
        "\n  # LINE掲載メタ(タイトル/説明文 JA+EN)専用更新。既存 update の\n"
        "  # sync_themes/sync_attribute_values(destroy_all)は通さない。\n"
        "  def update_line_meta\n"
        "    if @pack.update(line_meta_params)\n"
        '      redirect_to admin_linestamp_pack_path(@pack), notice: "LINE掲載メタ情報を更新しました"\n'
        "    else\n"
        '      redirect_to admin_linestamp_pack_path(@pack), alert: @pack.errors.full_messages.join(", ")\n'
        "    end\n"
        "  end\n"
    )
    s = s.replace("\n  def upload_sheet", action + "\n  def upload_sheet", 1)
    params = (
        "\n  def line_meta_params\n"
        "    params.require(:linestamp_pack).permit(:line_title_ja, :line_title_en, :line_desc_ja, :line_desc_en)\n"
        "  end\n"
    )
    s = s.replace("\n  def sync_themes", params + "\n  def sync_themes", 1)
    write(p, s)
else:
    print("  skip: packs_controller")

# --- BrandsController: update_line_meta + line_meta_params ---
p = "app/controllers/admin/linestamp/brands_controller.rb"
s = read(p)
if "def update_line_meta" not in s:
    s = s.replace(
        "before_action :set_brand, only: %i[show update upload_base purge_base]",
        "before_action :set_brand, only: %i[show update update_line_meta upload_base purge_base]",
        1,
    )
    action = (
        "\n  def update_line_meta\n"
        "    if @brand.update(line_meta_params)\n"
        '      redirect_to admin_linestamp_brand_path(@brand), notice: "LINE クリエイター情報を更新しました"\n'
        "    else\n"
        '      redirect_to admin_linestamp_brand_path(@brand), alert: @brand.errors.full_messages.join(", ")\n'
        "    end\n"
        "  end\n"
    )
    s = s.replace("\n  def upload_base", action + "\n  def upload_base", 1)
    params = (
        "\n  def line_meta_params\n"
        "    params.require(:linestamp_brand).permit(:line_creator_name, :line_copyright)\n"
        "  end\n"
    )
    s = s.replace("\n  def sync_themes", params + "\n  def sync_themes", 1)
    write(p, s)
else:
    print("  skip: brands_controller")

# --- StampsController: update_tags + tags_params ---
p = "app/controllers/admin/linestamp/stamps_controller.rb"
s = read(p)
if "def update_tags" not in s:
    s = s.replace(
        "before_action :set_stamp, only: %i[show update upload_processed reset designer_kit]",
        "before_action :set_stamp, only: %i[show update update_tags upload_processed reset designer_kit]",
        1,
    )
    action = (
        "\n  # 検索タグ(search_keywords)専用更新。カンマ区切り→配列、最大9個に丸める。\n"
        "  def update_tags\n"
        "    raw = params.dig(:linestamp_stamp, :search_keywords).to_s\n"
        "    tags = raw.split(/[,\\u3001\\n]/).map(&:strip).reject(&:blank?).uniq.first(9)\n"
        "    if @stamp.update(search_keywords: tags)\n"
        '      redirect_to admin_linestamp_stamp_path(@stamp), notice: "タグを更新しました(#{tags.size}/9)"\n'
        "    else\n"
        '      redirect_to admin_linestamp_stamp_path(@stamp), alert: @stamp.errors.full_messages.join(", ")\n'
        "    end\n"
        "  end\n"
    )
    s = s.replace("\n  def reset", action + "\n  def reset", 1)
    write(p, s)
else:
    print("  skip: stamps_controller")

# ===========================================================================
# ビュー: 各 show の <%# ALL_COLUMNS_DUMP %> の前にカードを挿入
# ===========================================================================
DUMP = "<%# ALL_COLUMNS_DUMP %>"

# --- packs/show: 固定値カード + メタ編集カード + Cowork プロンプト ---
p = "app/views/admin/linestamp/packs/show.html.erb"
s = read(p)
if "LINE_META_CARD" not in s:
    card = '''<%# LINE_META_CARD %>
<div class="card" style="margin-top:16px;">
  <h2>LINE Creators 固定設定(全スタンプ共通・LINECreator側で管理)</h2>
  <dl class="profile-grid">
    <dt>種類</dt><dd>スタンプ</dd>
    <dt>言語</dt><dd>日本語</dd>
    <dt>AIの使用</dt><dd>あり</dd>
    <dt>販売エリア</dt><dd>全エリア</dd>
    <dt>写真の使用</dt><dd>含まない</dd>
    <dt>アレンジ</dt><dd>参加しない</dd>
    <dt>Collaboration</dt><dd>参加しない</dd>
    <dt>販売開始</dt><dd>手動で開始</dd>
  </dl>
</div>

<div class="card" style="margin-top:16px;">
  <h2>LINE掲載メタ情報(タイトル / 説明文 — 日本語 + 英語)</h2>
  <%= form_with url: update_line_meta_admin_linestamp_pack_path(@pack), method: :patch do %>
    <div style="margin-bottom:10px;">
      <label style="display:block; font-size:12px; color:#a0aec0;">タイトル(日本語・40文字以内)</label>
      <input type="text" name="linestamp_pack[line_title_ja]" value="<%= @pack.line_title_ja %>" maxlength="40"
             oninput="document.getElementById('cnt-tja').textContent=this.value.length"
             style="width:100%; padding:6px; box-sizing:border-box;">
      <span style="font-size:11px; color:#718096;"><span id="cnt-tja"><%= @pack.line_title_ja.to_s.length %></span>/40</span>
    </div>
    <div style="margin-bottom:10px;">
      <label style="display:block; font-size:12px; color:#a0aec0;">Title (English, max 40)</label>
      <input type="text" name="linestamp_pack[line_title_en]" value="<%= @pack.line_title_en %>" maxlength="40"
             oninput="document.getElementById('cnt-ten').textContent=this.value.length"
             style="width:100%; padding:6px; box-sizing:border-box;">
      <span style="font-size:11px; color:#718096;"><span id="cnt-ten"><%= @pack.line_title_en.to_s.length %></span>/40</span>
    </div>
    <div style="margin-bottom:10px;">
      <label style="display:block; font-size:12px; color:#a0aec0;">説明文(日本語・160文字以内)</label>
      <textarea name="linestamp_pack[line_desc_ja]" maxlength="160" rows="3"
                oninput="document.getElementById('cnt-dja').textContent=this.value.length"
                style="width:100%; padding:6px; box-sizing:border-box;"><%= @pack.line_desc_ja %></textarea>
      <span style="font-size:11px; color:#718096;"><span id="cnt-dja"><%= @pack.line_desc_ja.to_s.length %></span>/160</span>
    </div>
    <div style="margin-bottom:10px;">
      <label style="display:block; font-size:12px; color:#a0aec0;">Description (English, max 160)</label>
      <textarea name="linestamp_pack[line_desc_en]" maxlength="160" rows="3"
                oninput="document.getElementById('cnt-den').textContent=this.value.length"
                style="width:100%; padding:6px; box-sizing:border-box;"><%= @pack.line_desc_en %></textarea>
      <span style="font-size:11px; color:#718096;"><span id="cnt-den"><%= @pack.line_desc_en.to_s.length %></span>/160</span>
    </div>
    <button type="submit" class="btn btn-primary btn-sm">保存</button>
  <% end %>

  <% if @pack.line_meta_prompt.present? %>
    <h3 style="margin-top:16px; font-size:13px;">英語版・タグ生成プロンプト(Cowork に貼り付けて実行)</h3>
    <pre id="line-meta-prompt" style="background:#232637; padding:12px; border-radius:6px; white-space:pre-wrap; font-size:12px; color:#e2e8f0; max-height:260px; overflow-y:auto;"><%= @pack.line_meta_prompt %></pre>
    <button type="button" onclick="navigator.clipboard.writeText(document.getElementById('line-meta-prompt').textContent)" class="btn btn-primary btn-sm" style="margin-top:8px;">📋 プロンプトをコピー</button>
  <% end %>
</div>

'''
    s = s.replace(DUMP, card + DUMP, 1)
    write(p, s)
else:
    print("  skip: packs/show")

# --- brands/show: クリエイター情報カード ---
p = "app/views/admin/linestamp/brands/show.html.erb"
s = read(p)
if "LINE_META_BRAND_CARD" not in s:
    card = '''<%# LINE_META_BRAND_CARD %>
<div class="card" style="margin-top:16px;">
  <h2>LINE クリエイター情報(ブランド共通)</h2>
  <%= form_with url: update_line_meta_admin_linestamp_brand_path(@brand), method: :patch do %>
    <div style="margin-bottom:10px;">
      <label style="display:block; font-size:12px; color:#a0aec0;">クリエイター名</label>
      <input type="text" name="linestamp_brand[line_creator_name]" value="<%= @brand.line_creator_name %>"
             style="width:100%; padding:6px; box-sizing:border-box;">
    </div>
    <div style="margin-bottom:10px;">
      <label style="display:block; font-size:12px; color:#a0aec0;">コピーライト(50文字以内)</label>
      <input type="text" name="linestamp_brand[line_copyright]" value="<%= @brand.line_copyright %>" maxlength="50"
             oninput="document.getElementById('cnt-cr').textContent=this.value.length"
             style="width:100%; padding:6px; box-sizing:border-box;">
      <span style="font-size:11px; color:#718096;"><span id="cnt-cr"><%= @brand.line_copyright.to_s.length %></span>/50</span>
    </div>
    <button type="submit" class="btn btn-primary btn-sm">保存</button>
  <% end %>
</div>

'''
    s = s.replace(DUMP, card + DUMP, 1)
    write(p, s)
else:
    print("  skip: brands/show")

# --- stamps/show: タグ編集カード(最大9) ---
p = "app/views/admin/linestamp/stamps/show.html.erb"
s = read(p)
if "LINE_TAGS_CARD" not in s:
    card = '''<%# LINE_TAGS_CARD %>
<div class="card" style="margin-top:16px;">
  <h2>検索タグ(最大9個 / LINEトークのサジェスト用)</h2>
  <%= form_with url: update_tags_admin_linestamp_stamp_path(@stamp), method: :patch do %>
    <input type="text" name="linestamp_stamp[search_keywords]"
           value="<%= (@stamp.search_keywords || []).join(', ') %>"
           placeholder="カンマ区切りで入力(例: おつかれ, 在宅, ねこ)"
           style="width:100%; padding:6px; box-sizing:border-box;">
    <p style="font-size:11px; color:#718096; margin-top:4px;">
      カンマ区切り。10個目以降は自動で切り捨てられます。現在: <%= (@stamp.search_keywords || []).size %>/9
    </p>
    <button type="submit" class="btn btn-primary btn-sm">タグを保存</button>
  <% end %>
</div>

'''
    s = s.replace(DUMP, card + DUMP, 1)
    write(p, s)
else:
    print("  skip: stamps/show")
PYEOF3

# ---------------------------------------------------------------------------
# コミット & プッシュ(変更がある時のみ)
# ---------------------------------------------------------------------------
echo "==> 変更内容"
git add -A
if git diff --cached --quiet; then
  echo "変更なし(既に適用済み)。push をスキップします。"
  exit 0
fi

git status --short

git commit -m "feat(linestamp): LINE申請メタ追加(固定値カード/タイトル説明文 JA+EN 40・160/タグ最大9)

- Pack に line_title_ja/en・line_desc_ja/en・line_meta_prompt を追加(schema手編集+migration)
- Brand に line_creator_name・line_copyright を追加
- 日本語タイトル/説明文は作成時に決定論で自動生成。英語は翻訳エンジン不在のため
  Cowork 貼り付け用プロンプトを自動生成しコピーボタンで提示
- 検索タグは既存 search_keywords を流用し管理画面で編集(最大9・作成時に候補自動投入)
- 専用 update_line_meta / update_tags アクションを新設(既存 destroy_all 同期を回避)"

echo "==> origin/main へ push(自動デプロイが起動します)"
git push origin "$BRANCH"

echo "==> 完了"
