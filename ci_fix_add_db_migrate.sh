#!/usr/bin/env bash
#
# ci_fix_add_db_migrate.sh
# ------------------------------------------------------------------
# CI修正: CI ワークフローで Rails を起動する各ジョブ
# (job-check / route-check / seed-check / test) の
# `bin/rails db:test:prepare` の直後に `bin/rails db:migrate` を挿入する。
#
# === なぜ落ちていたか ===
#   db/migrate/20260602120000_add_line_market_meta.rb が db/schema.rb に
#   反映されていない。各ジョブは db:schema:load でテストDBを作るため、
#   その1本が「未適用」のまま残り、rspec 起動時の maintain_test_schema! が
#   PendingMigrationError で abort。seed-check 等も同じ起動経路で巻き添え。
#   → schema:load 済みDBに対し db:migrate を「テスト直前(=test:prepare の後)」
#     に流すと、未反映の1本だけが適用され CI が緑に戻る。
#   ※ test:prepare の「前」に置くと test:prepare がスキーマを再ロードして
#     migrate を打ち消すため、必ず「後」に置く。
#
# === なぜ ローカルで ruby を叩かないか ===
#   原田さんのマシンには ruby が無い。このスクリプトは workflow YAML を
#   awk で書き換えて push するだけ。ruby/rails は叩かない。
#   実際の db:migrate は CI(self-hosted runner)が実行する。
#
# 冪等: 既に db:migrate が入っていれば二重挿入しない。差分なしなら push スキップ。
# 使い方: リポジトリのルート(myapp)で  bash ci_fix_add_db_migrate.sh
# ------------------------------------------------------------------
set -euo pipefail

if [ ! -f Gemfile ] || [ ! -f config/application.rb ]; then
  echo "ERROR: リポジトリのルートで実行してください (myapp で bash ci_fix_add_db_migrate.sh)" >&2
  exit 1
fi

echo "==> main を origin に同期"
git fetch origin main
git checkout main
git reset --hard origin/main

echo "==> CI ワークフローファイルを特定"
# seed-check の rake タスクはこの CI ワークフロー固有なのでマーカーに使う
WF="$(grep -rl 'linestamp:validate_imports' .github/workflows/ 2>/dev/null | head -n1 || true)"
if [ -z "${WF}" ] || [ ! -f "${WF}" ]; then
  echo "ERROR: 対象 CI ワークフロー(.github/workflows/ 配下で linestamp:validate_imports を含むファイル)が見つかりません" >&2
  exit 1
fi
echo "   対象: ${WF}"

BEFORE="$(grep -c 'bin/rails db:test:prepare' "${WF}" || true)"
echo "   db:test:prepare の出現数: ${BEFORE}"

echo "==> db:test:prepare の直後に bin/rails db:migrate を挿入（インデント踏襲・冪等）"
awk '
{
  lines[NR] = $0
}
END {
  for (i = 1; i <= NR; i++) {
    print lines[i]
    if (lines[i] ~ /bin\/rails db:test:prepare[[:space:]]*$/) {
      # 直後が既に db:migrate なら挿入しない（冪等）
      if (lines[i+1] !~ /bin\/rails db:migrate[[:space:]]*$/) {
        match(lines[i], /^[[:space:]]*/)
        print substr(lines[i], 1, RLENGTH) "bin/rails db:migrate"
      }
    }
  }
}
' "${WF}" > "${WF}.tmp"
mv "${WF}.tmp" "${WF}"

AFTER="$(grep -c 'bin/rails db:migrate' "${WF}" || true)"
echo "   挿入後 db:migrate の出現数: ${AFTER}"

echo "==> commit & push"
git add "${WF}"
if git diff --cached --quiet; then
  echo "   差分なし — 既に db:migrate が入っているようです。push をスキップ。"
else
  git commit -m "ci: run db:migrate after db:test:prepare to apply pending migration

db/schema.rb が add_line_market_meta(20260602120000) を反映しておらず、
db:schema:load のみでテストDBを作る job-check/route-check/seed-check/test が
PendingMigrationError で失敗していた。test:prepare 済みDBに対しテスト直前で
db:migrate を流し、未反映の1本を適用して CI を緑に戻す。"
  git push origin main
  echo "   push 完了。CI(self-hosted runner)で db:migrate が走り、4ジョブが緑になる想定。"
fi

echo
echo "============================================================"
echo " 完了: CI に db:migrate ステップを追加 (${WF})"
echo " ▼ 確認: GitHub Actions の job-check / route-check / seed-check / test"
echo "============================================================"
