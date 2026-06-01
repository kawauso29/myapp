#!/usr/bin/env bash
# 旧雛形ベースの pending ブランド企画ファイルを archived/ に退避する。
# 退避後、新雛形ベースで GitHub Actions の linestamp-brand-planning を回して作り直す。
set -euo pipefail
cd "$(dirname "$0")/../.."

src="db/seeds/linestamp/imports/pending"
dst="db/seeds/linestamp/imports/archived"
mkdir -p "$dst"

moved=0
for f in "$src"/*_brand_*.rb; do
  [ -e "$f" ] || continue
  name="$(basename "$f")"
  if git ls-files --error-unmatch "$f" >/dev/null 2>&1; then
    git mv "$f" "$dst/$name"
  else
    mv "$f" "$dst/$name"
  fi
  echo "archived: $name"
  moved=$((moved + 1))
done

echo ""
if [ "$moved" -gt 0 ]; then
  echo "done. ${moved} file(s) archived. 次: コミット&push → linestamp-brand-planning を再実行して新雛形で作り直す"
else
  echo "no pending brand files to archive."
fi
