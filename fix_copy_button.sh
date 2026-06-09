#!/usr/bin/env bash
#
# fix_copy_button.sh
# ------------------------------------------------------------------
# パック詳細のコピーボタンが効かない問題を直す。
#
# 原因:
#   navigator.clipboard.writeText() は HTTPS / localhost のセキュアコンテキスト
#   でしか動かない。平文 HTTP(http://133.167.124.112 等)で開くと
#   navigator.clipboard が undefined になり、クリックしても無言で失敗する。
#
# 対策:
#   フォールバック付き共通関数 copyPrompt(id, btn) を view に追加し、
#   既存の各ボタンの onclick をこの関数呼び出しに置換する。
#     1. セキュアなら navigator.clipboard.writeText を使う
#     2. ダメなら textarea + document.execCommand('copy')
#     3. それも無理なら本文を選択状態にして手動コピーを促す
#   コピー成功時はボタン表示を一時的に「コピーしました」に変える。
#
# 対象は show.html.erb 内の全 navigator.clipboard.writeText(...) ボタン
# (既存「Copy Prompt」+ あれば「Copy Cowork Prompt」)を一括変換する。
#
# === 実行順の注意 ===
#   このスクリプトは「最後」に実行すること。先に add_cowork_prompt.sh で
#   Cowork プロンプトカードを入れてから本スクリプトを流すと、両方のボタンが
#   まとめて修正される。冪等なので後から再実行しても安全。
#
# 変更は view 1枚のみ。controller / routes は変更しない。
# ARTS213 には ruby が無いので ruby / rails / rspec は一切叩かない。
# ------------------------------------------------------------------
set -euo pipefail

cd ~/source/myapp

echo "==> main を origin に同期"
git fetch origin main
git checkout main
git reset --hard origin/main

echo "==> コピーボタンをフォールバック対応に置換(冪等)"
python3 - <<'PY'
import re

p = "app/views/admin/linestamp/packs/show.html.erb"
s = open(p, encoding="utf-8").read()

# 1) 共通ヘルパJSを追加(まだ無ければ)
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

# 2) 全 navigator.clipboard.writeText(document.getElementById('XXX').textContent) を
#    copyPrompt('XXX', this) に置換(自然に冪等 — 置換後はマッチしない)
pat = re.compile(
    r"navigator\.clipboard\.writeText\(\s*document\.getElementById\(\s*'([^']+)'\s*\)\.textContent\s*\)"
)
new_s, n = pat.subn(lambda m: "copyPrompt('%s', this)" % m.group(1), s)
s = new_s
print("buttons: %d 件のボタンを copyPrompt 呼び出しに変換" % n)

open(p, "w", encoding="utf-8").write(s)
PY

echo "==> commit & push"
git add -A
if git diff --cached --quiet; then
  echo "差分なし — 既に適用済みのようです。push をスキップ。"
else
  git commit -m "fix(linestamp): コピーボタンを非HTTPSでも動くフォールバック式に修正

navigator.clipboard はセキュアコンテキスト限定のため平文HTTPで無反応だった。
copyPrompt(id, btn) を追加し、execCommand フォールバック + 最終的な選択表示で
HTTP環境でもコピーできるようにする。既存の全コピーボタンを一括変換。"
  git push origin main
  echo "push 完了。CI 通過後に自動デプロイされます。"
fi
