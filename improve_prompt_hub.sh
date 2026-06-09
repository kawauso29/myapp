#!/usr/bin/env bash
#
# improve_prompt_hub.sh
# ------------------------------------------------------------------
# パック詳細を「1ページで完結するプロンプト集約ページ」に改善する。
#
# 目的:
#   各スタンプの Designer Kit ZIP を毎回展開して読ませる運用がしんどいので、
#   ブランド / シリーズ / 各スタンプのプロンプトを1ページに集約し、必要な
#   ものだけを上から順に Cowork に貼り付けて実行できるようにする。
#
# 表示(show.html.erb の Sheet Prompt カードの直前に追加):
#   1. ブランドのプロンプト   … base_image があれば画像も表示
#   2. シリーズのプロンプト   … sheet_image があれば画像も表示
#   3. 各スタンプのプロンプト … processed_image があれば画像も表示
#
# コピー範囲(スコープ):
#   ブランド  → ブランドのみ
#   シリーズ  → ブランド ＋ シリーズ
#   スタンプ  → ブランド ＋ シリーズ ＋ 該当スタンプ
#   (連結プロンプトは display:none の <pre> に持たせ、コピー時だけ使う)
#
# コピーは copyPrompt(id, btn)(非HTTPSフォールバック対応)を使う。未導入なら
# 同じヘルパJSをこのスクリプトでも追記する(fix_copy_button.sh と同一・冪等)。
#
# 既存カード(Sheet Prompt / Stamps 表 等)は消さず "追加" するだけ。view 1枚のみ。
# ARTS213 には ruby が無いので ruby / rails / rspec は一切叩かない。
# ------------------------------------------------------------------
set -euo pipefail

cd ~/source/myapp

echo "==> main を origin に同期"
git fetch origin main
git checkout main
git reset --hard origin/main

echo "==> show.html.erb にプロンプト集約ページを追加(冪等)"
python3 - <<'PY'
import re

p = "app/views/admin/linestamp/packs/show.html.erb"
s = open(p, encoding="utf-8").read()

PRE = ("background:#232637; padding:12px; border-radius:6px; white-space:pre-wrap; "
       "font-size:12px; color:#e2e8f0; max-height:300px; overflow-y:auto;")

# 1) プロンプト集約カードを Sheet Prompt カードの直前に挿入
if "PROMPT_HUB" in s:
    print("hub: 既に存在 — スキップ")
else:
    anchor = '<div class="card" style="margin-top:16px;">\n  <h2>Sheet Prompt</h2>'
    if anchor not in s:
        raise SystemExit("hub: アンカー(Sheet Prompt カード)が見つからない — 手動確認が必要")

    card = r'''<%# PROMPT_HUB %>
<div class="card" style="margin-top:16px;">
  <h2>プロンプト集約（1ページ）</h2>
  <p style="color:#718096; font-size:12px; margin-bottom:12px;">
    必要なプロンプトを上から順に Cowork に貼り付けて実行できます。コピー範囲は
    ブランド＝ブランドのみ／シリーズ＝ブランド＋シリーズ／スタンプ＝ブランド＋シリーズ＋該当スタンプ。
  </p>
  <%
    __sep = "\n\n========================================\n\n"
    __brand_p = @pack.brand.brand_prompt.to_s
    __series_p = @pack.sheet_prompt.to_s
    __series_combined = [__brand_p, __series_p].reject(&:blank?).join(__sep)
  %>

  <h3 style="margin-top:4px;">1. ブランドのプロンプト</h3>
  <% if @pack.brand.base_image.attached? %>
    <p><%= image_tag url_for(@pack.brand.base_image), style: "max-width:160px; border-radius:8px;" %></p>
  <% end %>
  <% if __brand_p.present? %>
    <pre id="hub-brand-prompt" style="__PRE__"><%= __brand_p %></pre>
    <button onclick="copyPrompt('hub-brand-prompt', this)" class="btn btn-primary btn-sm" style="margin-top:8px;">📋 ブランドをコピー</button>
  <% else %>
    <p style="color:#718096;">ブランドのプロンプト未生成。</p>
  <% end %>

  <h3 style="margin-top:20px;">2. シリーズのプロンプト</h3>
  <% if @pack.sheet_image.attached? %>
    <p><%= image_tag url_for(@pack.sheet_image), style: "max-width:240px; border-radius:8px;" %></p>
  <% end %>
  <% if __series_p.present? %>
    <pre id="hub-series-prompt" style="__PRE__"><%= __series_p %></pre>
    <pre id="hub-series-combined" style="display:none;"><%= __series_combined %></pre>
    <button onclick="copyPrompt('hub-series-combined', this)" class="btn btn-primary btn-sm" style="margin-top:8px;">📋 ブランド＋シリーズをコピー</button>
  <% else %>
    <p style="color:#718096;">シリーズのプロンプト未生成。</p>
  <% end %>

  <h3 style="margin-top:20px;">3. 各スタンプのプロンプト</h3>
  <% @stamps.each do |__s| %>
    <% __stamp_combined = [__brand_p, __series_p, __s.prompt.to_s].reject(&:blank?).join(__sep) %>
    <div style="border-top:1px solid #2d3748; padding-top:12px; margin-top:12px;">
      <h4 style="margin:0 0 6px;">#<%= __s.position %> <%= __s.display_label %><%= " / #{__s.intent}" if __s.intent.present? %></h4>
      <% if __s.processed_image.attached? %>
        <p><%= image_tag url_for(__s.processed_image), style: "max-width:120px; border-radius:8px;" %></p>
      <% end %>
      <% if __s.prompt.present? %>
        <pre id="hub-stamp-prompt-<%= __s.id %>" style="__PRE__"><%= __s.prompt %></pre>
        <pre id="hub-stamp-combined-<%= __s.id %>" style="display:none;"><%= __stamp_combined %></pre>
        <button onclick="copyPrompt('hub-stamp-combined-<%= __s.id %>', this)" class="btn btn-primary btn-sm" style="margin-top:8px;">📋 ブランド＋シリーズ＋#<%= __s.position %>をコピー</button>
      <% else %>
        <p style="color:#718096;">プロンプト未生成。</p>
      <% end %>
    </div>
  <% end %>
</div>

'''
    card = card.replace("__PRE__", PRE)
    s = s.replace(anchor, card + anchor, 1)
    print("hub: プロンプト集約カードを追加")

# 2) copyPrompt ヘルパJS(非HTTPSフォールバック)を追記(まだ無ければ)
if "COPY_HELPER_JS" not in s:
    helper = r'''
<%# COPY_HELPER_JS %>
<script>
function copyPrompt(id, btn) {
  var el = document.getElementById(id);
  if (!el) { return; }
  var text = el.textContent;

  function flash() {
    if (!btn) { return; }
    var orig = btn.getAttribute("data-orig") || btn.textContent;
    btn.setAttribute("data-orig", orig);
    btn.textContent = "✅ コピーしました";
    setTimeout(function () { btn.textContent = orig; }, 1500);
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
    if (ok) {
      flash();
    } else {
      var r = document.createRange();
      r.selectNodeContents(el);
      var sel = window.getSelection();
      sel.removeAllRanges();
      sel.addRange(r);
      alert("自動コピーできませんでした。選択状態にしたので長押し→コピーしてください。");
    }
  }

  if (navigator.clipboard && window.isSecureContext) {
    navigator.clipboard.writeText(text).then(flash, legacyCopy);
  } else {
    legacyCopy();
  }
}
</script>
'''
    s = s.rstrip("\n") + "\n" + helper
    print("helper: copyPrompt 追加")
else:
    print("helper: 既に存在 — スキップ")

open(p, "w", encoding="utf-8").write(s)
PY

echo "==> commit & push"
git add -A
if git diff --cached --quiet; then
  echo "差分なし — 既に適用済みのようです。push をスキップ。"
else
  git commit -m "feat(linestamp): パック詳細にプロンプト集約(1ページ)を追加

ブランド/シリーズ/各スタンプのプロンプトを1ページに集約し、画像も併記。
コピー範囲はブランド=ブランドのみ/シリーズ=ブランド+シリーズ/
スタンプ=ブランド+シリーズ+該当スタンプ。連結文は隠しpreに保持。
コピーは非HTTPS対応の copyPrompt を使用。view 1枚のみの追加変更。"
  git push origin main
  echo "push 完了。CI 通過後に自動デプロイされます。"
fi
