#!/usr/bin/env bash
#
# add_line_submit_meta.sh
# ------------------------------------------------------------------
# LINE Creators Market 新規登録(申請)フォームの項目を管理画面で
# 「編集・保存 → コピペ」できるようにする(Option A: DBカラム追加)。
#
# 保存先の分担:
#   ブランド単位(全パック共通) … クリエイター名 / コピーライト / カテゴリ
#   パック単位(シリーズごと)   … タイトル(日/英) / 説明文(日/英)
#   固定値(毎回同じ)          … 画面に静的表示するだけ(DB不要)
#       スタンプ / 日本語 / AI使用 / 全エリア / 写真なし /
#       アレンジ参加しない / Collaboration参加しない / 手動で販売開始
#
# 各項目に 📋 コピーボタン(非HTTPSでも動く copyField フォールバック付き)。
# 一度埋めれば申請時はコピーするだけ。
#
# 追加カラム:
#   linestamp_brands : line_creator_name / line_copyright / line_category (string)
#   linestamp_packs  : line_title_ja / line_title_en (string)
#                      line_desc_ja  / line_desc_en  (text)
#
# === CI の重要な前提 ===
#   ci.yml のテストDBは「db/schema.rb の db:schema:load」で作られる(migrate
#   ではない)。よって新カラムは migration だけでなく db/schema.rb にも手で
#   追記し version を上げる必要がある。本スクリプトは両方を行う。
#
# 保存は専用アクション update_line_meta を新設する(既存 update は
# sync_themes/sync_attribute_values を呼び、パラメータが無いと関連を
# destroy_all してしまうため、それを避けて line_* だけを更新する)。
#
# ARTS213 には ruby が無いので ruby / rails / rspec は一切叩かない。
# すべて冪等。再実行しても二重挿入しない(マーカー/存在ガード)。
# ------------------------------------------------------------------
set -euo pipefail

cd ~/source/myapp

echo "==> main を origin に同期"
git fetch origin main
git checkout main
git reset --hard origin/main

echo "==> migration を追加(無ければ)"
MIG=db/migrate/20260602000000_add_line_submission_fields.rb
if [ -f "$MIG" ]; then
  echo "migration: 既に存在 — スキップ"
else
  cat > "$MIG" <<'RUBY'
class AddLineSubmissionFields < ActiveRecord::Migration[8.1]
  def change
    add_column :linestamp_brands, :line_creator_name, :string, comment: "LINE申請: クリエイター名"
    add_column :linestamp_brands, :line_copyright, :string, comment: "LINE申請: コピーライト表記"
    add_column :linestamp_brands, :line_category, :string, comment: "LINE申請: キャラクター・カテゴリ"

    add_column :linestamp_packs, :line_title_ja, :string, comment: "LINE申請: タイトル(日本語) 最大40文字"
    add_column :linestamp_packs, :line_title_en, :string, comment: "LINE申請: タイトル(英語) 最大40文字"
    add_column :linestamp_packs, :line_desc_ja, :text, comment: "LINE申請: スタンプ説明文(日本語)"
    add_column :linestamp_packs, :line_desc_en, :text, comment: "LINE申請: スタンプ説明文(英語)"
  end
end
RUBY
  echo "migration: 作成 $MIG"
fi

echo "==> db/schema.rb にカラム追記 + version 更新(CIのschema:load対策・冪等)"
python3 - <<'PY'
import re

p = "db/schema.rb"
s = open(p, encoding="utf-8").read()

def add_columns(text, table, additions, first_col):
    if first_col in text:
        print("schema: %s 既に追加済み — スキップ" % table)
        return text
    start = text.index('create_table "%s"' % table)
    end = text.index("\n  end\n", start)
    block = text[start:end]
    idx = block.find("\n    t.index ")
    if idx == -1:
        raise SystemExit("schema: %s に t.index が見つからない — 手動確認が必要" % table)
    insert_at = start + idx + 1  # 先頭の t.index 行の直前(列定義の末尾)に挿入
    print("schema: %s にカラム追加" % table)
    return text[:insert_at] + additions + text[insert_at:]

brands_add = (
    '    t.string "line_category", comment: "LINE申請: キャラクター・カテゴリ"\n'
    '    t.string "line_copyright", comment: "LINE申請: コピーライト表記"\n'
    '    t.string "line_creator_name", comment: "LINE申請: クリエイター名"\n'
)
packs_add = (
    '    t.text "line_desc_en", comment: "LINE申請: スタンプ説明文(英語)"\n'
    '    t.text "line_desc_ja", comment: "LINE申請: スタンプ説明文(日本語)"\n'
    '    t.string "line_title_en", comment: "LINE申請: タイトル(英語) 最大40文字"\n'
    '    t.string "line_title_ja", comment: "LINE申請: タイトル(日本語) 最大40文字"\n'
)

s = add_columns(s, "linestamp_brands", brands_add, '"line_creator_name"')
s = add_columns(s, "linestamp_packs", packs_add, '"line_title_ja"')

# version を migration のタイムスタンプ以上に引き上げる(古い場合のみ)
m = re.search(r"define\(version: (\d{4}_\d{2}_\d{2}_\d{6})\)", s)
if not m:
    raise SystemExit("schema: version 行が見つからない — 手動確認が必要")
cur = int(m.group(1).replace("_", ""))
mine = 20260602000000
if cur < mine:
    s = s.replace("version: %s" % m.group(1), "version: 2026_06_02_000000", 1)
    print("schema: version %s -> 2026_06_02_000000" % m.group(1))
else:
    print("schema: version は既に最新(%s) — 据え置き" % m.group(1))

open(p, "w", encoding="utf-8").write(s)
PY

echo "==> packs_controller に update_line_meta を追加(冪等)"
python3 - <<'PY'
p = "app/controllers/admin/linestamp/packs_controller.rb"
s = open(p, encoding="utf-8").read()

if "update_line_meta" in s:
    print("packs_controller: 既に存在 — スキップ")
else:
    # 1) before_action の only: 配列に追加
    if "only: %i[show " not in s:
        raise SystemExit("packs_controller: before_action アンカーが見つからない — 手動確認が必要")
    s = s.replace("only: %i[show ", "only: %i[show update_line_meta ", 1)

    # 2) public アクションを private の直前に挿入
    action = (
        "\n"
        "  def update_line_meta\n"
        "    if @pack.update(line_meta_params)\n"
        '      redirect_to admin_linestamp_pack_path(@pack), notice: "LINE申請メタデータを保存しました"\n'
        "    else\n"
        '      redirect_to admin_linestamp_pack_path(@pack), alert: "保存に失敗しました: #{@pack.errors.full_messages.join(\', \')}"\n'
        "    end\n"
        "  end\n"
    )
    if "\n  private\n" not in s:
        raise SystemExit("packs_controller: private アンカーが見つからない — 手動確認が必要")
    s = s.replace("\n  private\n", action + "\n  private\n", 1)

    # 3) strong params(line_* のみ。sync_* は呼ばない)
    params_m = (
        "  def line_meta_params\n"
        "    params.require(:linestamp_pack).permit(:line_title_ja, :line_title_en, :line_desc_ja, :line_desc_en)\n"
        "  end\n\n"
    )
    if "  def pack_params\n" not in s:
        raise SystemExit("packs_controller: pack_params アンカーが見つからない — 手動確認が必要")
    s = s.replace("  def pack_params\n", params_m + "  def pack_params\n", 1)

    open(p, "w", encoding="utf-8").write(s)
    print("packs_controller: update_line_meta + line_meta_params 追加")
PY

echo "==> brands_controller に update_line_meta を追加(冪等)"
python3 - <<'PY'
p = "app/controllers/admin/linestamp/brands_controller.rb"
s = open(p, encoding="utf-8").read()

if "update_line_meta" in s:
    print("brands_controller: 既に存在 — スキップ")
else:
    if "only: %i[show " not in s:
        raise SystemExit("brands_controller: before_action アンカーが見つからない — 手動確認が必要")
    s = s.replace("only: %i[show ", "only: %i[show update_line_meta ", 1)

    action = (
        "\n"
        "  def update_line_meta\n"
        "    if @brand.update(line_meta_params)\n"
        '      redirect_to admin_linestamp_brand_path(@brand), notice: "LINE申請メタデータ(ブランド)を保存しました"\n'
        "    else\n"
        '      redirect_to admin_linestamp_brand_path(@brand), alert: "保存に失敗しました: #{@brand.errors.full_messages.join(\', \')}"\n'
        "    end\n"
        "  end\n"
    )
    if "\n  private\n" not in s:
        raise SystemExit("brands_controller: private アンカーが見つからない — 手動確認が必要")
    s = s.replace("\n  private\n", action + "\n  private\n", 1)

    params_m = (
        "  def line_meta_params\n"
        "    params.require(:linestamp_brand).permit(:line_creator_name, :line_copyright, :line_category)\n"
        "  end\n\n"
    )
    if "  def brand_params\n" not in s:
        raise SystemExit("brands_controller: brand_params アンカーが見つからない — 手動確認が必要")
    s = s.replace("  def brand_params\n", params_m + "  def brand_params\n", 1)

    open(p, "w", encoding="utf-8").write(s)
    print("brands_controller: update_line_meta + line_meta_params 追加")
PY

echo "==> routes に patch :update_line_meta を追加(冪等)"
python3 - <<'PY'
p = "config/routes.rb"
s = open(p, encoding="utf-8").read()
if "update_line_meta" in s:
    print("routes: 既に存在 — スキップ")
else:
    changed = False
    # packs member: export_for_line の後に追加
    a_pack = "          get :export_for_line\n"
    if a_pack in s:
        s = s.replace(a_pack, a_pack + "          patch :update_line_meta\n", 1)
        changed = True
    else:
        raise SystemExit("routes: packs アンカー(get :export_for_line)が見つからない — 手動確認が必要")
    # brands member: upload_base の後に追加
    a_brand = "          post :upload_base\n"
    if a_brand in s:
        s = s.replace(a_brand, a_brand + "          patch :update_line_meta\n", 1)
        changed = True
    else:
        raise SystemExit("routes: brands アンカー(post :upload_base)が見つからない — 手動確認が必要")
    if changed:
        open(p, "w", encoding="utf-8").write(s)
        print("routes: packs/brands に patch :update_line_meta 追加")
PY

echo "==> show.html.erb(pack/brand)に申請メタカードと copyField を追加(冪等)"
python3 - <<'PY'
FIELD = ("flex:1; background:#1a1d2b; color:#e2e8f0; border:1px solid #2d3748; "
         "border-radius:6px; padding:8px; font-size:13px;")

HELPER = r'''
<%# COPY_FIELD_JS %>
<script>
function copyField(id, btn) {
  var el = document.getElementById(id);
  if (!el) { return; }
  var text = (el.value !== undefined && el.value !== null && el.value !== "") ? el.value : (el.textContent || "");

  function flash() {
    if (!btn) { return; }
    var orig = btn.getAttribute("data-orig") || btn.textContent;
    btn.setAttribute("data-orig", orig);
    btn.textContent = "✅";
    setTimeout(function () { btn.textContent = orig; }, 1200);
  }
  function legacyCopy() {
    var ta = document.createElement("textarea");
    ta.value = text;
    ta.setAttribute("readonly", "");
    ta.style.position = "fixed";
    ta.style.top = "0";
    ta.style.left = "0";
    ta.style.opacity = "0";
    document.body.appendChild(ta);
    ta.focus();
    ta.select();
    try { ta.setSelectionRange(0, text.length); } catch (e) {}
    var ok = false;
    try { ok = document.execCommand("copy"); } catch (e) { ok = false; }
    document.body.removeChild(ta);
    if (ok) { flash(); }
    else { alert("自動コピーできませんでした。手動でコピーしてください。"); }
  }
  if (navigator.clipboard && window.isSecureContext) {
    navigator.clipboard.writeText(text).then(flash, legacyCopy);
  } else {
    legacyCopy();
  }
}
</script>
'''

def add_helper(s):
    if "COPY_FIELD_JS" in s:
        return s, False
    return s.rstrip("\n") + "\n" + HELPER, True

# ---------- パック画面 ----------
pp = "app/views/admin/linestamp/packs/show.html.erb"
ps = open(pp, encoding="utf-8").read()

if "LINE_SUBMIT_META" in ps:
    print("pack view: カード既存 — スキップ")
else:
    anchor = "<%# ALL_COLUMNS_DUMP %>\n"
    if anchor not in ps:
        raise SystemExit("pack view: ALL_COLUMNS_DUMP アンカーが見つからない — 手動確認が必要")
    card = r'''<%# LINE_SUBMIT_META %>
<div class="card" style="margin-top:16px;">
  <h2>LINE申請メタデータ</h2>
  <p style="color:#718096; font-size:12px; margin-bottom:12px;">
    LINE Creators Market の新規登録フォームに貼り付ける項目です。保存しておけば申請時はコピーするだけ。
  </p>

  <%= form_with url: update_line_meta_admin_linestamp_pack_path(@pack), method: :patch, scope: :linestamp_pack do |f| %>
    <div style="margin-bottom:12px;">
      <label style="display:block; color:#a0aec0; font-size:12px; margin-bottom:4px;">タイトル（日本語）<span style="color:#718096;"> ／最大40文字</span></label>
      <div style="display:flex; gap:8px; align-items:flex-start;">
        <%= f.text_field :line_title_ja, id: "line-title-ja", value: @pack.line_title_ja, maxlength: 40, style: "__FIELD__" %>
        <button type="button" onclick="copyField('line-title-ja', this)" class="btn btn-secondary btn-sm">📋</button>
      </div>
    </div>
    <div style="margin-bottom:12px;">
      <label style="display:block; color:#a0aec0; font-size:12px; margin-bottom:4px;">タイトル（英語）<span style="color:#718096;"> ／最大40文字</span></label>
      <div style="display:flex; gap:8px; align-items:flex-start;">
        <%= f.text_field :line_title_en, id: "line-title-en", value: @pack.line_title_en, maxlength: 40, style: "__FIELD__" %>
        <button type="button" onclick="copyField('line-title-en', this)" class="btn btn-secondary btn-sm">📋</button>
      </div>
    </div>
    <div style="margin-bottom:12px;">
      <label style="display:block; color:#a0aec0; font-size:12px; margin-bottom:4px;">スタンプ説明文（日本語）</label>
      <div style="display:flex; gap:8px; align-items:flex-start;">
        <%= f.text_area :line_desc_ja, id: "line-desc-ja", value: @pack.line_desc_ja, rows: 3, style: "__FIELD__" %>
        <button type="button" onclick="copyField('line-desc-ja', this)" class="btn btn-secondary btn-sm">📋</button>
      </div>
    </div>
    <div style="margin-bottom:12px;">
      <label style="display:block; color:#a0aec0; font-size:12px; margin-bottom:4px;">スタンプ説明文（英語）</label>
      <div style="display:flex; gap:8px; align-items:flex-start;">
        <%= f.text_area :line_desc_en, id: "line-desc-en", value: @pack.line_desc_en, rows: 3, style: "__FIELD__" %>
        <button type="button" onclick="copyField('line-desc-en', this)" class="btn btn-secondary btn-sm">📋</button>
      </div>
    </div>
    <%= f.submit "💾 保存", class: "btn btn-primary btn-sm" %>
  <% end %>

  <h3 style="margin-top:20px;">ブランド共通（<%= @pack.brand.character_name %>）</h3>
  <p style="color:#718096; font-size:12px; margin-bottom:8px;">
    クリエイター名／コピーライト／カテゴリはブランド単位です。<a href="<%= admin_linestamp_brand_path(@pack.brand) %>" style="color:#63b3ed;">ブランド画面</a>で編集できます。
  </p>
  <dl class="profile-grid">
    <dt>クリエイター名</dt>
    <dd>
      <span id="line-brand-creator"><%= @pack.brand.line_creator_name.presence || "（未設定）" %></span>
      <% if @pack.brand.line_creator_name.present? %><button type="button" onclick="copyField('line-brand-creator', this)" class="btn btn-secondary btn-sm">📋</button><% end %>
    </dd>
    <dt>コピーライト</dt>
    <dd>
      <span id="line-brand-copyright"><%= @pack.brand.line_copyright.presence || "（未設定）" %></span>
      <% if @pack.brand.line_copyright.present? %><button type="button" onclick="copyField('line-brand-copyright', this)" class="btn btn-secondary btn-sm">📋</button><% end %>
    </dd>
    <dt>カテゴリ</dt>
    <dd>
      <span id="line-brand-category"><%= @pack.brand.line_category.presence || "（未設定）" %></span>
      <% if @pack.brand.line_category.present? %><button type="button" onclick="copyField('line-brand-category', this)" class="btn btn-secondary btn-sm">📋</button><% end %>
    </dd>
  </dl>

  <h3 style="margin-top:20px;">固定値（毎回同じ）</h3>
  <dl class="profile-grid">
    <dt>スタンプのタイプ</dt><dd>スタンプ</dd>
    <dt>表現する言語</dt><dd>日本語</dd>
    <dt>AIの利用</dt><dd>使用</dd>
    <dt>配信エリア</dt><dd>全エリア</dd>
    <dt>写真の有無</dt><dd>写真は含まれない</dd>
    <dt>スタンプアレンジ機能</dt><dd>参加しない</dd>
    <dt>LINE Creators Collaboration</dt><dd>参加しない</dd>
    <dt>審査連携設定</dt><dd>手動で販売開始</dd>
  </dl>
</div>

'''
    card = card.replace("__FIELD__", FIELD)
    ps = ps.replace(anchor, card + anchor, 1)
    print("pack view: LINE申請メタカード追加")

ps, added = add_helper(ps)
print("pack view: copyField %s" % ("追加" if added else "既存"))
open(pp, "w", encoding="utf-8").write(ps)

# ---------- ブランド画面 ----------
bp = "app/views/admin/linestamp/brands/show.html.erb"
bs = open(bp, encoding="utf-8").read()

if "LINE_BRAND_META" in bs:
    print("brand view: カード既存 — スキップ")
else:
    anchor = "<%# ALL_COLUMNS_DUMP %>\n"
    if anchor not in bs:
        raise SystemExit("brand view: ALL_COLUMNS_DUMP アンカーが見つからない — 手動確認が必要")
    card = r'''<%# LINE_BRAND_META %>
<div class="card" style="margin-top:16px;">
  <h2>LINE申請メタデータ（ブランド共通）</h2>
  <p style="color:#718096; font-size:12px; margin-bottom:12px;">
    このブランドの全パックで共通して使う申請項目です。各パック詳細画面にも表示されます。
  </p>
  <%= form_with url: update_line_meta_admin_linestamp_brand_path(@brand), method: :patch, scope: :linestamp_brand do |f| %>
    <div style="margin-bottom:12px;">
      <label style="display:block; color:#a0aec0; font-size:12px; margin-bottom:4px;">クリエイター名</label>
      <div style="display:flex; gap:8px; align-items:flex-start;">
        <%= f.text_field :line_creator_name, id: "brand-line-creator", value: @brand.line_creator_name, style: "__FIELD__" %>
        <button type="button" onclick="copyField('brand-line-creator', this)" class="btn btn-secondary btn-sm">📋</button>
      </div>
    </div>
    <div style="margin-bottom:12px;">
      <label style="display:block; color:#a0aec0; font-size:12px; margin-bottom:4px;">コピーライト</label>
      <div style="display:flex; gap:8px; align-items:flex-start;">
        <%= f.text_field :line_copyright, id: "brand-line-copyright", value: @brand.line_copyright, style: "__FIELD__" %>
        <button type="button" onclick="copyField('brand-line-copyright', this)" class="btn btn-secondary btn-sm">📋</button>
      </div>
    </div>
    <div style="margin-bottom:12px;">
      <label style="display:block; color:#a0aec0; font-size:12px; margin-bottom:4px;">キャラクター・カテゴリ</label>
      <div style="display:flex; gap:8px; align-items:flex-start;">
        <%= f.text_field :line_category, id: "brand-line-category", value: @brand.line_category, style: "__FIELD__" %>
        <button type="button" onclick="copyField('brand-line-category', this)" class="btn btn-secondary btn-sm">📋</button>
      </div>
    </div>
    <%= f.submit "💾 保存", class: "btn btn-primary btn-sm" %>
  <% end %>
</div>

'''
    card = card.replace("__FIELD__", FIELD)
    bs = bs.replace(anchor, card + anchor, 1)
    print("brand view: LINE申請メタカード追加")

bs, added = add_helper(bs)
print("brand view: copyField %s" % ("追加" if added else "既存"))
open(bp, "w", encoding="utf-8").write(bs)
PY

echo "==> commit & push"
git add -A
if git diff --cached --quiet; then
  echo "差分なし — 既に適用済みのようです。push をスキップ。"
else
  git commit -m "feat(linestamp): LINE申請メタデータの編集・コピー欄を管理画面に追加

ブランド単位(クリエイター名/コピーライト/カテゴリ)とパック単位
(タイトル日英/説明文日英)のカラムを追加し、各項目にコピーボタンを付与。
固定値(タイプ/言語/AI/配信エリア等)は静的表示。保存は専用 update_line_meta で
行い、既存 update の sync_* による関連 destroy を回避。CI の schema:load 対策で
db/schema.rb も手で更新(version 2026_06_02_000000)。"
  git push origin main
  echo "push 完了。CI 通過後に自動デプロイされます。"
fi
