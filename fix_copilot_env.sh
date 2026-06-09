#!/usr/bin/env bash
# =============================================================================
# Copilot が「0ファイルPR(Initial plan だけ)」しか作れない根本原因の修正。
# ※ self-hosted runner は変えない(ユーザー指示)。直すのは Ruby 用意ステップだけ。
#
# 原因:
#   .github/workflows/copilot-setup-steps.yml の「Setup Ruby via rbenv」ステップが
#     echo "$HOME/.rbenv/bin"   >> "$GITHUB_PATH"
#     echo "$HOME/.rbenv/shims" >> "$GITHUB_PATH"
#   という rbenv 前提。これは VPS(self-hosted runner)にしか ~/.rbenv が無いから
#   成立しているだけ。Copilot コーディングエージェントが自前の環境を組んで
#   このステップを実行すると、rbenv が無く Ruby/gem が入らない →
#   seed を書いても ruby -c / rubocop / rspec で検証できず、検証前提の
#   リポジトリ指示を満たせないまま初期空コミットだけ残す = Files changed 0。
#
# 修正(runner は self-hosted のまま):
#   rbenv ハックのステップを公式 ruby/setup-ruby@v1 に置換。
#   ruby-version: 3.3.7(.ruby-version と一致) / bundler-cache: true で
#   bundle install + キャッシュ。rbenv の有無に関係なく Ruby 3.3.7 + gem が入る。
#   → エージェントが検証して実ファイルを commit できる。
#   VPS 上で走る場合も setup-ruby は自前で ruby を用意するので問題なし。
#
#   使い方: リポジトリのルート(~/source/myapp)で  bash fix_copilot_env.sh
# =============================================================================
set -euo pipefail

if [ ! -f Gemfile ] || [ ! -f config/application.rb ]; then
  echo "ERROR: リポジトリのルートで実行してください (~/source/myapp で bash fix_copilot_env.sh)" >&2
  exit 1
fi

WF=".github/workflows/copilot-setup-steps.yml"
if [ ! -f "$WF" ]; then
  echo "ERROR: $WF が見つかりません。" >&2
  exit 1
fi

echo "==> 現在の runs-on(これは維持する):"
grep -n "runs-on" "$WF" | sed 's/^/   /'

echo "==> Ruby 用意ステップだけ公式 setup-ruby に置換(runner は self-hosted のまま)"
cat > "$WF" <<'YML'
name: "Copilot Setup Steps"

# GitHub Copilot コーディングエージェント専用。エージェントは PR 作業前に、
# ここに書かれた手順で自分の開発環境を構築する。job 名は必ず copilot-setup-steps。
# Ruby は rbenv 前提(VPS限定)にすると、エージェント環境で Ruby が入らず
# 検証できないため 0 ファイル PR になる。→ 公式 setup-ruby で環境非依存に用意する。
on:
  workflow_dispatch:
  push:
    paths: [.github/workflows/copilot-setup-steps.yml]
  pull_request:
    paths: [.github/workflows/copilot-setup-steps.yml]

jobs:
  copilot-setup-steps:
    runs-on: [self-hosted, sakura-vps]
    permissions:
      contents: read
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      # .ruby-version(3.3.7) を読み、Ruby を入れて bundle install + キャッシュ。
      # rbenv の有無に関係なく動くので、エージェントの自前環境でも Ruby が揃う。
      - name: Setup Ruby 3.3.7 and install gems
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: "3.3.7"
          bundler-cache: true
YML

echo "==> 変更後:"
sed 's/^/   /' "$WF"

echo "==> コミット & push"
git add "$WF"
if git diff --cached --quiet; then
  echo "   差分なし。既に修正済み。"
  exit 0
fi
git commit -m "Fix Copilot agent env: provision Ruby via official setup-ruby (rbenv-only step caused 0-file PRs); keep self-hosted runner"
git push origin main

echo
echo "============================================================"
echo " 完了。self-hosted runner は維持、Ruby 用意ステップだけ直しました。"
echo
echo " ▼ 確認:"
echo "   gh run list --workflow=copilot-setup-steps.yml -L 3"
echo "   → ✓ になればOK。"
echo
echo " ▼ 効果確認(次の Brand/Research Issue を Copilot に振った時):"
echo "   PR が Files changed > 0 になり、pending/ に seed が入る。"
echo "   その後は apply-imports が自動でレコード化。"
echo "============================================================"
