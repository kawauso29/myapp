#!/usr/bin/env bash
# RuboCop の Layout/TrailingEmptyLines (Final newline missing) を直す hotfix。
# 対象拡張子の全ファイルを走査し、末尾に \n が無いものに 1 つだけ付け足す。
#
# 使い方 (myapp ルートで):
#   bash scripts/lint/fix-trailing-newlines.sh
#
# 実行後はそのまま git status → コミット → push。

set -euo pipefail

cd "$(dirname "$0")/../.."

# 走査対象: Ruby 系 + 設定ファイル + view + spec
# 除外: tmp / vendor / node_modules / .git / log / public / storage
python3 - <<'PY'
import os, sys

ROOT = "."
TARGET_EXTS = (".rb", ".rake", ".gemspec", ".ruby", ".erb")
SKIP_DIRS = {".git", "tmp", "node_modules", "vendor", "log", "public", "storage", ".bundle"}

fixed = []
for root, dirs, files in os.walk(ROOT):
    # 上書き禁止ディレクトリを枝刈り
    dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
    for fn in files:
        if not fn.endswith(TARGET_EXTS):
            continue
        p = os.path.join(root, fn)
        with open(p, "rb") as f:
            data = f.read()
        if not data:
            continue
        if not data.endswith(b"\n"):
            with open(p, "ab") as f:
                f.write(b"\n")
            fixed.append(p)

if fixed:
    print(f"fixed {len(fixed)} file(s):")
    for p in fixed:
        print(f"  {p}")
else:
    print("no files needed fixing.")
PY

echo ""
echo "done. review with: git status"
