#!/usr/bin/env bash
# =============================================================================
# research / brand / pack ワークフローの cron(schedule)だけ止める。
# 手動実行(workflow_dispatch)は残す。→ しばらく手動対応で進めるため。
#
# なぜ gh workflow disable を使わないか:
#   gh workflow disable はワークフロー自体を無効化し、手動の "Run workflow" も
#   消えてしまう。今回は「自動cronだけ止めて手動は残す」ので不可。
#   → YAML の `schedule:` ブロックだけをコメントアウトする。
#
# 何をするか:
#   .github/workflows/ から research/brand/pack 系で `schedule:` を持つ yml を
#   自動検出し、`  schedule:` ブロック(配下の - cron 行含む)だけを # で無効化。
#   workflow_dispatch / jobs はそのまま。冪等(既にコメント済みなら触らない)。
#
#   復活させたい時: 各ファイルの `#  schedule:` 〜 `#    - cron` 行の # を外すだけ。
#
#   使い方: リポジトリのルート(~/source/myapp)で  bash disable_cron.sh
# =============================================================================
set -euo pipefail

if [ ! -f Gemfile ] || [ ! -f config/application.rb ]; then
  echo "ERROR: リポジトリのルートで実行してください (~/source/myapp で bash disable_cron.sh)" >&2
  exit 1
fi

WF_DIR=".github/workflows"
if [ ! -d "$WF_DIR" ]; then
  echo "ERROR: $WF_DIR が見つかりません。" >&2
  exit 1
fi

echo "==> 対象ワークフローを検出 (research/brand/pack かつ schedule: 持ち)"
CANDIDATES=()
for f in "$WF_DIR"/*.yml "$WF_DIR"/*.yaml; do
  [ -f "$f" ] || continue
  case "$f" in
    *research*|*brand*|*pack*) : ;;   # ファイル名で対象を絞る
    *) continue ;;
  esac
  # まだ有効な(コメントされていない) schedule: 行があるか
  if grep -Eq '^  schedule:[[:space:]]*$' "$f"; then
    CANDIDATES+=("$f")
  fi
done

if [ "${#CANDIDATES[@]}" -eq 0 ]; then
  echo "   有効な schedule: を持つ research/brand/pack ワークフローは見つかりませんでした。"
  echo "   (既に全て無効化済みか、ファイル名が想定と違う可能性)"
  echo "   現状の schedule 行一覧:"
  grep -RnE '^[# ]*  schedule:' "$WF_DIR" 2>/dev/null | sed 's/^/      /' || echo "      (なし)"
  exit 0
fi

echo "   対象:"
printf '      %s\n' "${CANDIDATES[@]}"

# -----------------------------------------------------------------------------
# `  schedule:` の行から、配下の連続する 4スペース以上インデント行 / 空行 を
# コメントアウト。次の 2スペース兄弟キー or トップレベルキーで終了。
for f in "${CANDIDATES[@]}"; do
  echo "==> 無効化: $f"
  tmp="$(mktemp)"
  awk '
    /^  schedule:[[:space:]]*$/ { inblk=1; print "#" $0; next }
    inblk == 1 {
      if ($0 ~ /^    / || $0 ~ /^[[:space:]]*$/) { print "#" $0; next }
      inblk = 0
    }
    { print }
  ' "$f" > "$tmp"
  mv "$tmp" "$f"
  echo "   --- 変更後の該当箇所 ---"
  grep -nE '^[# ]*  schedule:|^[# ]*    - cron' "$f" | sed 's/^/      /' || true
done

# -----------------------------------------------------------------------------
echo "==> コミット & push"
git add "${CANDIDATES[@]}"
if git diff --cached --quiet; then
  echo "   差分なし。既に無効化済み。"
  exit 0
fi
git commit -m "Disable scheduled cron for research/brand/pack workflows (manual dispatch only)"
git push origin main

echo
echo "============================================================"
echo " 完了。自動cronは停止、手動実行は引き続き可能です。"
echo
echo " ▼ 確認:"
echo "   gh workflow list"
echo "   # 各 yml で schedule がコメントアウトされているか:"
echo "   grep -RnE '^[# ]*  schedule:' .github/workflows/"
echo
echo " ▼ 手動で回したい時(例):"
echo "   gh workflow run linestamp-research.yml -f research_kind=base"
echo
echo " ▼ cronを復活させたい時:"
echo "   各ファイルの '#  schedule:' / '#    - cron' 行の先頭 # を外して push"
echo "============================================================"
