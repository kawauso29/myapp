#!/usr/bin/env bash
#
# add_cowork_prompt.sh
# ------------------------------------------------------------------
# パック詳細(admin/linestamp/packs/show.html.erb)に
# 「Cowork取り込みプロンプト」カードを追加して main に push する。
#
# 何をするか:
#   - そのパックの position→label/intent 対応表を埋め込んだ、Coworkに
#     そのまま貼り付けられるプロンプト文字列をサーバ側(ERB)で生成して表示
#   - 「📋 Copy Cowork Prompt」ボタンでクリップボードにコピー(既存の
#     "📋 Copy Prompt" と同じ navigator.clipboard パターン)
#   - main/tab は「position 1 の元画像から Cowork で作成しZIPに同梱」する
#     運用に合わせた指示文を含める
#
# 変更ファイルは view 1枚のみ。controller / routes は変更不要。
#   app/views/admin/linestamp/packs/show.html.erb  ← カード追記(冪等)
#
# ARTS213 には ruby が無いので ruby / rails / rspec は一切叩かない。
# CI(ci.yml)が lint + test を回し、通れば自動デプロイされる。
# ------------------------------------------------------------------
set -euo pipefail

cd ~/source/myapp

echo "==> main を origin に同期"
git fetch origin main
git checkout main
git reset --hard origin/main

echo "==> show.html.erb に Cowork取り込みプロンプトカードを追加(冪等)"
python3 - <<'PY'
p = "app/views/admin/linestamp/packs/show.html.erb"
s = open(p, encoding="utf-8").read()

if "COWORK_IMPORT_PROMPT" in s:
    print("view: 既に存在 — スキップ")
    raise SystemExit(0)

anchor = "<%# ALL_COLUMNS_DUMP %>\n"
if anchor not in s:
    raise SystemExit("view: アンカー(ALL_COLUMNS_DUMP)が見つからない — 手動確認が必要")

card = r'''<%# COWORK_IMPORT_PROMPT %>
<div class="card" style="margin-top:16px;">
  <h2>Cowork取り込みプロンプト</h2>
  <p style="color:#718096; font-size:12px; margin-bottom:8px;">
    グリーンバックのスタンプを Cowork の input/ にまとめてアップし、この内容を貼り付けてください。
    各画像を見て position を判定 → 透過 → 取り込み用 ZIP まで自動で作成されます。
  </p>
  <%
    __lines = []
    __lines << "input/ のグリーンバックPNGを line-stamp-packaging スキルで処理してください。"
    __lines << "各画像を見て、下の position 対応表に突き合わせて position 番号を判定し、"
    __lines << "リネーム・透過して取り込み用 ZIP(output/line_import.zip)を作成してください。"
    __lines << "完成 ZIP はこの Cowork 画面でダウンロードします(Teams/メール添付は不要)。"
    __lines << ""
    __lines << "【パック】#{@pack.brand.character_name} / #{@pack.series_theme}"
    __lines << ""
    __lines << "position 対応表:"
    @stamps.each do |__s|
      __label = __s.label.presence || "(ラベル未設定)"
      __row = "  #{__s.position}: #{__label}"
      __row += " / #{__s.intent}" if __s.intent.present?
      __lines << __row
    end
    __lines << ""
    __lines << "main画像: position 1 の元画像を main.png(240x240, 透過なし)として同梱"
    __lines << "tab画像:  position 1 の元画像を tab.png(96x74, 透過あり)として同梱"
    __lines << ""
    __lines << "実行例:"
    __lines << "  python scripts/transparency_pipeline.py pack \\"
    __lines << "    --map  working/stamp_map.json \\"
    __lines << "    --out  output/line_import.zip \\"
    __lines << "    --main <position1の元ファイル> \\"
    __lines << "    --tab  <position1の元ファイル>"
    __lines << ""
    __lines << "処理後、出力 ZIP をこのパック詳細の「⬆️ Upload LINE Zip」に渡せば全添付完了です。"
    __cowork_prompt = __lines.join("\n")
  %>
  <pre id="cowork-prompt" style="background:#232637; padding:12px; border-radius:6px; white-space:pre-wrap; font-size:12px; color:#e2e8f0; max-height:360px; overflow-y:auto;"><%= __cowork_prompt %></pre>
  <button onclick="navigator.clipboard.writeText(document.getElementById('cowork-prompt').textContent)" class="btn btn-primary btn-sm" style="margin-top:8px;">📋 Copy Cowork Prompt</button>
</div>

'''

s = s.replace(anchor, card + anchor, 1)
open(p, "w", encoding="utf-8").write(s)
print("view: Cowork取り込みプロンプトカード追加")
PY

echo "==> commit & push"
git add -A
if git diff --cached --quiet; then
  echo "差分なし — 既に適用済みのようです。push をスキップ。"
else
  git commit -m "feat(linestamp): パック詳細にCowork取り込みプロンプト出力を追加

position->label/intent 対応表を埋め込んだ貼り付け用プロンプトをERBで生成し、
Copy Cowork Prompt ボタンで取得できるようにする。main/tab は position 1 の
元画像から Cowork で作成しZIP同梱する運用を指示文に明記。view 1枚のみの変更。"
  git push origin main
  echo "push 完了。CI 通過後に自動デプロイされます。"
fi
