#!/usr/bin/env bash
# 廃止された Linestamp 関連ファイルを冪等に削除するスクリプト。
#
# 削除対象 (いずれも dead config / 廃止された cron 経路):
#   - app/jobs/linestamp/daily_orchestrator_job.rb
#   - spec/jobs/linestamp/daily_orchestrator_job_spec.rb
#   - config/schedule.yml                (SolidQueue は config/recurring.yml を読む)
#
# 使い方 (myapp ルートで):
#   bash scripts/linestamp/cleanup-deprecated-files.sh
#
# 実行後はそのままコミット → push でデプロイに乗せる。

set -euo pipefail

# このスクリプトが置かれている scripts/linestamp/ から myapp ルートへ降りる
cd "$(dirname "$0")/../.."

paths=(
  "app/jobs/linestamp/daily_orchestrator_job.rb"
  "spec/jobs/linestamp/daily_orchestrator_job_spec.rb"
  "config/schedule.yml"
)

removed_any=0
for p in "${paths[@]}"; do
  if [ -e "$p" ]; then
    # git 管理下なら git rm、追跡外なら通常 rm
    if git ls-files --error-unmatch "$p" >/dev/null 2>&1; then
      git rm -f "$p"
    else
      rm -f "$p"
    fi
    echo "removed: $p"
    removed_any=1
  else
    echo "skip   : $p (already gone)"
  fi
done

if [ "$removed_any" -eq 1 ]; then
  echo ""
  echo "done. review with: git status"
  echo "then commit:       git commit -m 'chore(linestamp): remove deprecated cron files'"
else
  echo ""
  echo "nothing to remove."
fi
