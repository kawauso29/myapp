#!/usr/bin/env bash
#
# fix_upload_size.sh
# ------------------------------------------------------------------
# 「413 Request Entity Too Large」(nginx)を解決する。
#
# 原因:
#   nginx の client_max_body_size 既定値は約1MB。ベース画像 / スタンプ /
#   LINE申請ZIP をアップロードするとこの上限を超え、Puma(Rails)に届く前に
#   nginx が 413 を返している。画面に nginx/1.18.0 と出ているのが証拠。
#
# 対策:
#   /etc/nginx/conf.d/client_max_body_size.conf を作成し、http コンテキストで
#   client_max_body_size を 50m に引き上げる。Ubuntu の nginx.conf は
#   http {} 内で conf.d/*.conf を include しているので、これで全 server に効く。
#
# === 実行場所(重要) ===
#   これは Rails リポジトリの push ではなく、デプロイ先 VPS 側の nginx 設定変更。
#   ★ デプロイ先 VPS で実行すること:  ubuntu@133.167.124.112
#   （ARTS213 ではなく VPS。sudo が必要）
#
# 冪等。再実行しても同じ内容を書き直して reload するだけ。
# ------------------------------------------------------------------
set -euo pipefail

CONF=/etc/nginx/conf.d/client_max_body_size.conf
SIZE=50m

echo "==> ${CONF} に client_max_body_size ${SIZE} を設定"
echo "client_max_body_size ${SIZE};" | sudo tee "${CONF}" >/dev/null

echo "==> nginx 設定テスト"
sudo nginx -t

echo "==> nginx を reload(無停止)"
sudo systemctl reload nginx

echo
echo "完了: アップロード上限を ${SIZE} に引き上げました。"
echo "ブラウザを更新して再度アップロードしてください。"
